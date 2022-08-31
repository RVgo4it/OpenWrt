#!/bin/sh

# This script will report on data usage in a bandwidthd SQLite databse.  
# need packages bandwidthd-sqlite sqlite3-cli

# cutover daily, weekly or monthly (D, W or M)
CUT=D
CUTDESC=Daily
CUTNOTE=
# cutover day (if CUT=W) as number where sat=0.  (if CUT=M) as day of month.
CUTDAY=0
# cutover hour 0-23
CUTHOUR=12
# look this many cutover
SPANS=10
# bytes scale
BYTES=1
SBYTES=Kbytes
# quota.  
QUOTA=0
# include or exclude IP addresses.  default total.
QUERY=T
ADDRESSES=

for P in "$@"; do
  set -- ${P//=/ } 
  case $1 in
    "-d" | "--daily")
      CUT=D
      CUTDESC=Daily
    ;;
    "-w" | "--weekday")
      CUT=W
      CUTDESC=Weekly
      [[ "$2" != "" ]] && CUTDAY=$2
    ;;
    "-m" | "--monthly")                                                                                       
      CUT=M
      CUTDESC=Monthly
      CUTDAY=01                                                                                                   
      [[ "$2" != "" ]] && CUTDAY=$2                                                                           
    ;;                                                                                                        
    "-h" | "--hour")
      CUTHOUR=$2
    ;;
    "-s" | "--spans")                                                                                                                                                                                      
      SPANS=$2                                                                                                                                                                                             
    ;;                                                                                                                                                                                                     
    "-b" | "--bytes")                                                                         
      [[ "$2" == "k" ]] && BYTES=1 && SBYTES=Kbytes                                                                          
      [[ "$2" == "m" ]] && BYTES=1024 && SBYTES=Mbytes                                                                           
      [[ "$2" == "g" ]] && BYTES=$((1024*1024)) && SBYTES=Gbytes                                                                            
    ;; 
    "-q" | "--quota")                                                                                                                                             
      QUOTA=$2                                                                                                                                 
    ;;
    "-x" | "--exclude")
      QUERY=X                                                                                                                                                             
      ADDRESSES=$2
    ;;
    "-i" | "--include")                                                                                                                                             
      QUERY=I                                                                                                                                                       
      ADDRESSES=$2
    ;;                                                                                                                                                  
    "-n" | "--note")                                                                                    
      CUTNOTE=$2 
    ;;                                                                                                                                                              
    *)
      echo "Syntax Error $1: Arguments are as follows:"
      echo "  -d --daily         Turnover is daily.  Default."
      echo "  -w --weekly[=n]    Turnover is weekly.  Default is Sat(0)."
      echo "  -m --monthly[=n]   Turnover is monthly. For day of month, use n. Default is first(1)."
      echo "  -h --hour=n        Turnover hour, 00-23.  Default is 12."
      echo "  -s --spans=n       Look back this many turnover spans.  Default is 10."
      echo "  -b --bytes=x       Scale the bytes, k, m or g.  Default is Kbytes."
      echo "  -q --quota=x       Report % of quota.  Also, return non zero (250) if current span over quota.  Default 1 Tbytes."
      echo "  -x --exclude=s     Exclude comma separated list of dotted IP addresses from total in report."
      echo "  -i --include=s     Include only comma separated list of dotted IP addresses in report."
      echo "  -n --note=s        Include short note on the report title."
      exit 0
    ;;
  esac
done

[[ "$CUTNOTE" != "" ]] && CUTDESC="$CUTDESC $CUTNOTE"

# calc the quota
if [ $QUOTA -eq 0 ]; then
  QUOTA=$((1024*1024*1024/BYTES))
fi

if [ $CUT == W ]; then                                                                                                                                                                                      
  DAYS=7                                                                                                                                                                                                   
else                                                                                                                                                                                                       
  DAYS=1                                                                                                                                                                                                   
fi

# return day of week as sat = 0 (or the cut over day = 0).  $1 is date as YYYY-MM-DD hh:mm:ss
dayofweek() {
  echo $(((`date -d "$1" "+%u"` + 1 - $CUTDAY) % 7))
}

# return timestamp.  date is $1.                                                                                                                                                                           
ts() {                                                                                                                                                                                                     
  echo `date -d "$1" "+%s"`                                                                                                                                                                                
}                                                                                                                                                                                                          

# add/sub seconds to date.  $1 is date.  $2 is seconds
addsubdate() {
  local TS=$(ts "$1")    
  local TS=$(($TS + $2))
  date -d @$TS '+%Y-%m-%d %H:%M'
}

# add/sub months to date.  $1 is date.  $2 is months.
addsubmonth() {
  local M=`date -d "$1" '+%m'`
  local M=${M#0}
  local M=$((M + $2))
  local D=`date -d "$1" "+%Y-$M-%d %H:%M:%S"`
  date -d "$D" '+%Y-%m-%d %H:%M'
}
 
# return the datetime of last cutover
lastcutover() {
  local NOW=`date '+%Y-%m-%d %H:%M:%S'` 
  if [ $CUT = M ]; then
    local CUTOVER="`date '+%Y-%m'`-$CUTDAY $CUTHOUR:00"
  else  
    local CUTOVER="`date '+%Y-%m-%d'` $CUTHOUR:00"
    if [ $CUT = W ]; then 
      local CUTOVER=$(addsubdate "$CUTOVER" $(($(dayofweek $NOW) * -24 * 60 * 60)))
    fi
  fi
  if [[ $(ts "$NOW") -lt $(ts "$CUTOVER") ]]; then
    if [ $CUT = M ]; then
      local CUTOVER=$(addsubmonth "$CUTOVER" -1) 
    else
      local CUTOVER=$(addsubdate "$CUTOVER" $(($DAYS * -24 * 60 * 60)))
    fi
  fi
  echo $CUTOVER
}

unsigned_to_signed32() {
  if [[ $1 -ge $((0x80000000)) ]]; then
    echo $(($1 - 0x100000000))
  else
    echo $1
  fi
}

signed32_to_unsigned() {
  if [[ $1 -lt 0 ]]; then
    echo $(($1 + 0x100000000))
  else
    echo $1
  fi
}

# convert dotted ip address to u32 as used in database
ip_to_signed32() {
  local XIP_ADDR=`printf '%02X' ${1//./ }` 
  local USNIP_ADD=$((0x$XIP_ADDR))              
  echo $(unsigned_to_signed32 $USNIP_ADD )
} 

# any IP addresses to convert?
if [ $QUERY != T  ]; then
  QUERYIN=`(IFS=,; for IP in $ADDRESSES; do unset IFS; printf "$PARAM $(ip_to_signed32 $IP)"; PARAM=,; done;)`
fi

# start of report
echo Bandwidth Quota $CUTDESC Report for: `date "+%Y-%m-%d %H:%M"`
CUTOVER=$(lastcutover)

# end of cutover span
if [ $CUT = M ]; then
  LASTCUTOVER=$(addsubmonth "$CUTOVER" 1) 
else
  LASTCUTOVER=$(addsubdate "$CUTOVER" $(($DAYS * 24 * 60 * 60)))
fi
LASTCUTOVERTS=$(ts "$LASTCUTOVER")                                                                                                                                              

# get the database path
DB=`uci get bandwidthd.@bandwidthd[0].sqlite_filename`

# exit code
RET=0

# examine current and prev spans 
echo -e "Time span (from - to)\tTotal\tBytes\t% of $QUOTA $SBYTES" 
I=1
while [ $I -le $SPANS ]; do
  # get total bytes for this span
  CUTOVERTS=$(ts "$CUTOVER")
  # query the total tables for this span
  if [ $QUERY == T ]; then
    TOTAL=`sqlite3 $DB "select sum(total)/$BYTES as total from (\
                          SELECT sum(total) as total FROM bd_tx_total_log\
                            where timestamp < $LASTCUTOVERTS and timestamp > $CUTOVERTS\
                        union\
                          SELECT sum(total) as total FROM bd_rx_total_log\
                            where timestamp < $LASTCUTOVERTS and timestamp > $CUTOVERTS\
                        ) as txrx"`
  else
    # query the detail tables (via IP) for this span
    if [ $QUERY == X ]; then
      TOTAL=`sqlite3 $DB "select sum(total)/$BYTES as total from (\
                            SELECT sum(total) as total FROM bd_tx_log\
                              where timestamp < $LASTCUTOVERTS and timestamp > $CUTOVERTS and ip not in ($QUERYIN)\
                          union\
                            SELECT sum(total) as total FROM bd_rx_log\
                              where timestamp < $LASTCUTOVERTS and timestamp > $CUTOVERTS and ip not in ($QUERYIN)\
                          ) as txrx"`
    else
      TOTAL=`sqlite3 $DB "select sum(total)/$BYTES as total from (\
                            SELECT sum(total) as total FROM bd_tx_log\
                              where timestamp < $LASTCUTOVERTS and timestamp > $CUTOVERTS and ip in ($QUERYIN)\
                          union\
                            SELECT sum(total) as total FROM bd_rx_log\
                              where timestamp < $LASTCUTOVERTS and timestamp > $CUTOVERTS and ip in ($QUERYIN)\
                          ) as txrx"`
    fi
  fi
  TOTAL=$(($TOTAL+0))
  PERCENT=$((TOTAL * 100 / QUOTA ))
  echo -e "$CUTOVER - $LASTCUTOVER\t$TOTAL\t$SBYTES\t$PERCENT%" 

  # return (exit code) 1 if current span quota used up
  if [[ $I -eq 1 && $PERCENT -ge 100 ]]; then
    RET=250
  fi

  # start of this spand becomes end of next span
  LASTCUTOVER=$CUTOVER
  LASTCUTOVERTS=$CUTOVERTS                                                                                                                                                                                     

  # calc next spand to report on
  if [ $CUT = M ]; then
    CUTOVER=$(addsubmonth "$CUTOVER" -1) 
  else
    CUTOVER=$(addsubdate "$CUTOVER" $(($DAYS * -24 * 60 * 60)))
  fi
  I=$(($I+1))
done

# return w/ exit code
exit $RET


