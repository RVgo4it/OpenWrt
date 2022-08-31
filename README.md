# OpenWrt

For OpenWrt 21.02.3.  <br>

Syntax is: bandwidth_used.sh [arguments]<br>
Arguments are as follows:<br>
  -d --daily         Turnover is daily.  Default.<br>
  -w --weekly[=n]    Turnover is weekly.  Default is Sat(0).<br>
  -m --monthly[=n]   Turnover is monthly. For day of month, use n. Default is first(1).
  -h --hour=n        Turnover hour, 00-23.  Default is 12.
  -s --spans=n       Look back this many turnover spans.  Default is 10.
  -b --bytes=x       Scale the bytes, k, m or g.  Default is Kbytes.
  -q --quota=x       Report % of quota.  Also, return non zero if current span over quota.  Default 1 Tbytes.
  -x --exclude=s     Exclude comma separated list of dotted IP addresses from total in report.
  -i --include=s     Include only comma separated list of dotted IP addresses in report.
  -n --note=s        Include short note on the report title.

Syntax is: bandwidth_shape.sh start | stop [arguments]
Arguments are as follows:
  start | stop       Start or stop traffic shaping.  Required.
  -d --download=nbit Download speed in bits/s.  Default is 1Mbit.
  -u --upload=nbit   Upload speed in bits/s.  Default is 500Kbit.
  -x --exclude=s     Exclude comma separated list of dotted IP addresses from traffic shaping.
  -i --include=s     Include only comma separated list of dotted IP addresses in traffic shaping. 

