#!/bin/ash

# This script will simulate bandwidthd-sqlite's database.  it just looks at internet traffic.  
# It also collects IPv6 data and mac addresses.
# It uses tcpdump to collect packets for a pac file in one process.
# A second process totals the sizes in those pac files for each ip/mac pair, rx and tx.
# 3rd process imports the totals into the sqlite db.  

# required:
# install tcpdump lsof sqlite3-cli
# need a thumb drive mounted at /mnt/sda1

# help pass the SIGTERM/SIGINT to child processes
signal_exit() {
  echo $(date +%H:%M:%S) "Received SIGINT"
  kill -INT $PCAPPID
  kill -TERM $SQLITEPID
  wait
  exit 0
}
trap signal_exit SIGINT

# IPv4 functions
ip2int()
{
    echo $1 | { IFS=. read a b c d; echo $(((((((a << 8) | b) << 8) | c) << 8) | d)); }
}
int2ip()
{
    local ui32=$1; shift
    local ip n
    for n in 1 2 3 4; do
        ip=$((ui32 & 0xff))${ip:+.}$ip
        ui32=$((ui32 >> 8))
    done
    echo $ip
}

echo $(date +%H:%M:%S) This script PID=$$

# interface for local LAN
LOCALIF=$(uci get network.lan.device)
echo $(date +%H:%M:%S) LOCALIF=$LOCALIF
# 5 minute snaps
SEC=$((5*60))
echo $(date +%H:%M:%S) SEC=$SEC
# 4Mb buffer
BUFFKB=4096
echo $(date +%H:%M:%S) BUFFKB=$BUFFKB
# dir path for capture files
CAP=/mnt/sda1/pcaps
mkdir -p $CAP
echo $(date +%H:%M:%S) CAP=$CAP
# file path for sqlite3 db file
DBPATH=/mnt/sda1/pcapdb
DB=$DBPATH/db.sqlite
mkdir -p $DBPATH
echo $(date +%H:%M:%S) DB=$DB
# IPv4 address of the router
ROUTERIP4=$(uci get network.lan.ipaddr)
ROUTERIP4MASK=$(uci get network.lan.netmask)
echo $(date +%H:%M:%S) ROUTERIP4=$ROUTERIP4
# IPv6 address of the router - the IPv6 addressed used by hosts for default route
ROUTERIP6=$(ip -6 a show dev $(uci get network.lan.device)|awk '{ if ($1 == "inet6" && $4 == "link" ) { split($2,ip,"/"); print ip[1]; } }')
echo $(date +%H:%M:%S) ROUTERIP6=$ROUTERIP6
# MACaddress of the router
ROUTERMAC=$(ip -f link a show dev $(uci get network.lan.device)|awk '{ if ($1 == "link/ether") print $2 }')
# calc subnet
IP4INT=$(ip2int $ROUTERIP4)
MASKINT=$(ip2int $ROUTERIP4MASK)
SUBNET=$(int2ip $((IP4INT & MASKINT)))/$(echo $MASKINT| awk '{ x=xor($1,0xffffffff)+1; y=32-log(x)/log(2); print y; }')
echo $(date +%H:%M:%S) SUBNET=$SUBNET
echo $(date +%H:%M:%S) ROUTERMAC=$ROUTERMAC
TAB="$(printf '\t')"
cat >/etc/config/bandwidthd <<-EOF
config bandwidthd
${TAB}option dev $LOCALIF
${TAB}option subnets "$SUBNET"
${TAB}option sqlite_filename "$DB"
EOF
# start capturing in background - ref: https://www.tcpdump.org/manpages/tcpdump.1.html
# collects packets send/received via default route
tcpdump -i $LOCALIF -B $BUFFKB -G $SEC -w "$CAP/%Y-%m-%d %H:%M:%S" "ether host $ROUTERMAC and ( ( ip and not ip host $ROUTERIP4 ) or ( ip6 and not ip6 host $ROUTERIP6 ) )" &
PCAPPID=$!
echo $(date +%H:%M:%S) PCAPPID=$PCAPPID

# create the DB tables
sqlite3 $DB "CREATE TABLE IF NOT EXISTS bd_rx_log (timestamp INT, ip, mac, total INT DEFAULT 0);"
sqlite3 $DB "CREATE INDEX IF NOT EXISTS bd_rx_log_pkey on bd_rx_log (timestamp, ip, mac);"
sqlite3 $DB "CREATE TABLE IF NOT EXISTS bd_tx_log (timestamp INT, ip, mac, total INT DEFAULT 0);"
sqlite3 $DB "CREATE INDEX IF NOT EXISTS bd_tx_log_pkey on bd_rx_log (timestamp, ip, mac);"

sqlite3 $DB "CREATE TABLE IF NOT EXISTS bd_rx_total_log (timestamp INT, total INT DEFAULT 0);"
sqlite3 $DB "CREATE INDEX IF NOT EXISTS bd_rx_total_log_pkey on bd_rx_log (timestamp);"
sqlite3 $DB "CREATE TABLE IF NOT EXISTS bd_tx_total_log (timestamp INT, total INT DEFAULT 0);"
sqlite3 $DB "CREATE INDEX IF NOT EXISTS bd_tx_total_log_pkey on bd_rx_log (timestamp);"

# look for *.SQL files - import to db as needed - as background
while [ 1 ]; do
    sleep 10
    for FSQL in $DBPATH/*.SQL; do
      [ -e "$FSQL" ] || continue;
      echo $(date +%H:%M:%S) File "$FSQL" processing...
      # run all inserts as batch
      if sqlite3 $DB -batch < "$FSQL" ; then
        # all good
        rm "$FSQL"
        echo $(date +%H:%M:%S) removed "$FSQL"
      else
        # failed
        echo $(date +%H:%M:%S) error for "$FSQL"
      fi
    done
done &
SQLITEPID=$!
echo $(date +%H:%M:%S) SQLITEPID=$SQLITEPID

# loop forever - looking for cap files
while [ 1 ]; do
  sleep 10
  for FCAP in $CAP/*; do
    [ -e "$FCAP" ] || continue;
    # maybe still writing to it?  if so, skip it.
    lsof "$FCAP" > /dev/null 2>&1 && { continue; }
    echo $(date +%H:%M:%S) File "$FCAP" processing...
    # data timestamp comes from cap file name
    TS=$(date -d "${FCAP##*/}" +%s)
    # write sql file for this cap file
    SQLFILE=$DBPATH/$TS.tmp
    echo $(date +%H:%M:%S) SQLFILE=$SQLFILE
    echo "BEGIN TRANSACTION;" >$SQLFILE
    # process all packats from cap file
    while read DIR MAC IP LEN; do
      # DIR is tx or rx
      TABLE=bd_${DIR}_log
      # sql stmt for total (len)
      echo "INSERT INTO $TABLE (timestamp, ip, mac, total)
        VALUES (
          $TS,
          '$IP',
          '$MAC',
          $LEN
        );" >> $SQLFILE
    done < <(tcpdump --immediate-mode -l -t -n -e -r "$FCAP" | \
        awk -v rtrmac=$ROUTERMAC '{
          # get packet length
          len=$8; sub(/:/,"",len);
          # from router mac, must be rx packet
          if ($1 == rtrmac) {
            # get mac and ip remove trailing ":"
            mac = substr($3, 1, length($3)-1);
            ip = substr($11, 1, length($11)-1);
            # remove last "." and after it (port #)
            sub(/\.[^.]*$/,"",ip);
            # total the packet len
            rxArr[mac " " ip] += len;
          } else {
            # get mac and ip
            mac=$1;
            ip=$9;
            # remove last "." and after it (port #)
            sub(/\.[^.]*$/,"",ip);
            # total the packet len
            txArr[mac " " ip] += len;
          }
        } END {
          # print rx totals
          for ( k in rxArr) {
            print "rx", k, rxArr[k];
          }
          # print tx totals
          for ( k in txArr) {
            print "tx", k, txArr[k];
          }
        }')
    echo "INSERT INTO bd_tx_total_log SELECT timestamp, SUM(total) as total FROM bd_tx_log WHERE timestamp=$TS;" >> $SQLFILE
    echo "INSERT INTO bd_rx_total_log SELECT timestamp, SUM(total) as total FROM bd_rx_log WHERE timestamp=$TS;" >> $SQLFILE
    echo "COMMIT;" >> $SQLFILE
    mv $SQLFILE $DBPATH/$TS.SQL
    echo $(date +%H:%M:%S) completed $DBPATH/$TS.SQL
    rm "$FCAP"
    echo $(date +%H:%M:%S) removed "$FCAP"
  done  
done


