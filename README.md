***Introduction***

I have been using OpenWrt for years.  It’s on all my routers except one.  It still has Gargoyle.  I would like to switch it over to OpenWrt.  For that, I need to be able to report daily, weekly and monthly Internet data usage.  I also need to be able to report totals and for all or an IP subset like the smart TVs.  Also, if usage is over a given quota, I want to restrict the bandwidth for all or just some devices.

I have not seen any posts here describing something like this.  I have been searching for awhile.  So, for the Gargoyle migration I made some notes and wrote some scripts.  I thought I would share.  Maybe someone has a similar need.  

Scripts are available at https://github.com/RVgo4it/OpenWrt.  

***Data Collection***

To collect the data, I decided on “bandwidthd-sqlite”.  It has nice graphs and I can easily pull the details I need from the SQLite database.  

To install, use these commands:

`opkg update; opkg install bandwidthd-sqlite sqlite3-cli`

To configure, we need to stop the service and check the configuration.  Use the following commands:


```
/etc/init.d/bandwidthd stop
uci show bandwidthd
```

Confirm the subnet and interface device is correct for the router.  If needed, adjust using commands like these:


```
uci set bandwidthd.@bandwidthd[0].subnets='192.168.n.0/24'
uci set bandwidthd.@bandwidthd[0].dev='br-lan'
uci commit bandwidthd
```

We need to fine tune the data capture.  We just want data to/from the Internet.  For this, we’ll need some info from the network interface.  Use this command:
```
 
ifconfig `uci get bandwidthd.@bandwidthd[0].dev`
```
 
Make note of the MAC address and the IP address.  Edit and use the following configuration commands:


```
uci set bandwidthd.@bandwidthd[0].filter='ip and ether host xx:xx:xx:xx:xx:xx and not host 192.168.n.1'
uci set bandwidthd.@bandwidthd[0].promiscuous='false'
uci commit bandwidthd
/etc/init.d/bandwidthd start
```

The filter will tell “bandwidthd” to only look at packets sent to/from the router but the router was not the sender or receiver.  Basically, that’s default route packets.

The path for the SQLite database is actually under /tmp, so it will be lost during a power cycle of the router.  However, we need that data.  So, use a thumb drive to save it on a regular schedule.  Create a folder on it called “bandwidthd” and add the following to LuCI → System → Scheduled Tasks.  This example will run every 10 minutes.  Adjust path and schedule as needed.  

```
*/10 * * * * DEST=/mnt/sda1/bandwidthd/stats.db;rm $DEST;sqlite3 `uci get bandwidthd.@bandwidthd[0].sqlite_filename` "vacuum into '$DEST'"
```

We’ll need to put the database file back before the service is started at boot time.  Disable auto-start with this command:

`/etc/init.d/bandwidthd disable`

Then add the following commands via LuCI → System → Startup and select the Local Startup tab.  Adjust the path as needed.


```
mkdir /tmp/bandwidthd
cp /mnt/sda1/bandwidthd/stats.db /tmp/bandwidthd
/etc/init.d/bandwidthd start
```

The database can grow quite large over time.  It should be cleaned up on a regular basis.  The following commands can be used to clean it of older records not needed any more.  This example keeps totals for 26 weeks and details for 8 weeks.  The commands can be placed in a script and scheduled to run weekly.


```
TOTALWEEKS=26
DETAILWEEKS=8
NOWTS=`date '+%s'`
TOTALTS=$((NOWTS - TOTALWEEKS * 7 * 24 * 60 * 60))
DETAILTS=$((NOWTS - DETAILWEEKS * 7 * 24 * 60 * 60))
DB=`uci get bandwidthd.@bandwidthd[0].sqlite_filename`
sqlite3 $DB 'DELETE FROM bd_rx_log WHERE timestamp < $DETAILTS;'
sqlite3 $DB 'DELETE FROM bd_tx_log WHERE timestamp < $DETAILTS;'
sqlite3 $DB 'DELETE FROM bd_rx_total_log WHERE timestamp < $TOTALTS;'
sqlite3 $DB 'DELETE FROM bd_tx_total_log WHERE timestamp < $TOTALTS;'
```

***Reporting***

To view the data as charts, use the IP address of your router and append “/bandwidthd” to it.  It will be something like http://192.168.1.1/bandwidthd.  

Note: The data for the charts does not come from the database.  So, after a power cycle, the charts will be missing older data.  However, the attached script “bandwidth_used.sh” will query the database that contains all the data.


```
Syntax is: bandwidth_used.sh [arguments]
Arguments are as follows:
  -d --daily         Turnover is daily.  Default.
  -w --weekly[=n]    Turnover is weekly.  Default is Sat(0).
  -m --monthly[=n]   Turnover is monthly. For day of month, use n. Default is first(1).
  -h --hour=n        Turnover hour, 00-23.  Default is 12.
  -s --spans=n       Look back this many turnover spans.  Default is 10.
  -b --bytes=x       Scale the bytes, k, m or g.  Default is Kbytes.
  -q --quota=x       Report % of quota.  Also, return non zero if current span over quota.  Default 1 Tbytes.
  -x --exclude=s     Exclude comma separated list of dotted IP addresses from total in report.
  -i --include=s     Include only comma separated list of dotted IP addresses in report.
  -n --note=s        Include short note on the report title.
```

For example, to query the daily 6 AM usage of the smart TV at 192.168.1.76, with a quota of 8 Gbytes, use this command:


```
./bandwidth_used.sh --note=TV --hour=06 --bytes=m --include=192.168.1.76 --quota=8192
Bandwidth Quota Daily TV Report for: 2022-28-29 15:28
Time span (from - to)	Total	Bytes	% of 8192 Mbytes
2022-08-29 06:00 - 2022-08-30 06:00	221	Mbytes	2%
2022-08-28 06:00 - 2022-08-29 06:00	6074	Mbytes	74%
2022-08-27 06:00 - 2022-08-28 06:00	0	Mbytes	0%
2022-08-26 06:00 - 2022-08-27 06:00	839	Mbytes	10%
2022-08-25 06:00 - 2022-08-26 06:00	3501	Mbytes	42%
2022-08-24 06:00 - 2022-08-25 06:00	7696	Mbytes	93%
2022-08-23 06:00 - 2022-08-24 06:00	0	Mbytes	0%
2022-08-22 06:00 - 2022-08-23 06:00	0	Mbytes	0%
2022-08-21 06:00 - 2022-08-22 06:00	0	Mbytes	0%
2022-08-20 06:00 - 2022-08-21 06:00	0	Mbytes	0%
```

To convert the report to HTML, pipe the report to the following awk command:


```
awk -F '\t' 'BEGIN { print "<!DOCTYPE html><html><body><table>" }\
  { if (substr($1,1,9) == "Bandwidth")\
  { print "<tr><td colspan='4' align='center'><b><h3>" $1 "</h3></b></td></tr>"} else\
  { print "<tr><td>" $1 "</td><td align='right'>" $2 "</td><td>" $3\
    "</td><td align='right'>" $4 "</td></tr>"} } END { print "</table></body></html>" }'
```

I use the HTML version of the reports for a custom page under /www/bandwidthd and for emails.  

***Traffic Shaping***

The “bandwidth_used.sh” returns an error code of 250 if the current time span, first row of the report, is 100% or more.  It can be used to trigger another script.  The triggered script could, for example, perform traffic shaping so as to limit the data usage for some or all devices.  

The attached “bandwidth_shape.sh” script uses qdisc CAKE to limit the upload and download speed.  It needs the traffic control packages.  Use this command to install them:

`opkg update; opkg install tc-full kmod-ifb kmod-sched-cake`

Details of the script are as follows:


```
Syntax is: bandwidth_shape.sh start | stop [arguments]
Arguments are as follows:
  start | stop       Start or stop traffic shaping.  Required.
  -d --download=nbit Download speed in bits/s.  Default is 1Mbit.
  -u --upload=nbit   Upload speed in bits/s.  Default is 500Kbit.
  -x --exclude=s     Exclude comma separated list of dotted IP addresses from traffic shaping.
  -i --include=s     Include only comma separated list of dotted IP addresses in traffic shaping.
```
 

For example, to shape the data usage for the smart TV to the defaults, forcing it to standard definition, use the following command:

`./bandwidth_shape.sh start --include=192.168.1.76` 

***Summary***

I hope others find this useful.  I have tested these procedures and scripts on OpenWrt 21.02.3.  I don’t know if they will work on older or future versions.  Also, I want to send a big thank you out to the OpenWrt team and supporters plus all the contributors on the forms for all their hard work on the awesome open source project called OpenWrt.