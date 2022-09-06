# OpenWrt

For OpenWrt 21.02.3.  

## `bandwidth_used.sh [arguments]`

```
Arguments are:
  -d --daily         Turnover is daily.  Default.<br>
  -w --weekly[=n]    Turnover is weekly.  Default is Sat(0).<br>
  -m --monthly[=n]   Turnover is monthly. For day of month, use n. Default is first(1).<br>
  -h --hour=n        Turnover hour, 00-23.  Default is 12.<br>
  -s --spans=n       Look back this many turnover spans.  Default is 10.<br>
  -b --bytes=x       Scale the bytes, k, m or g.  Default is Kbytes.<br>
  -q --quota=x       Report % of quota.  Also, return non zero if current span over quota.  Default 1 Tbytes.<br>
  -x --exclude=s     Exclude comma separated list of dotted IP addresses from total in report.<br>
  -i --include=s     Include only comma separated list of dotted IP addresses in report.<br>
  -n --note=s        Include short note on the report title.
```

## `bandwidth_shape.sh [ start | stop ] [arguments]`

```
Arguments are:
  start | stop       Start or stop traffic shaping.  Required.
  -d --download=nbit Download speed in bits/s.  Default is 1Mbit.
  -u --upload=nbit   Upload speed in bits/s.  Default is 500Kbit.
  -x --exclude=s     Exclude comma separated list of dotted IP addresses from traffic shaping.
  -i --include=s     Include only comma separated list of dotted IP addresses in traffic shaping. 
```
