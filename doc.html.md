<!DOCTYPE html>
<html>
<head>
	<meta http-equiv="content-type" content="text/html; charset=utf-8"/>
	<title></title>
	<meta name="generator" content="LibreOffice 7.3.5.2 (Linux)"/>
	<meta name="created" content="2022-08-29T13:43:03.426641555"/>
	<meta name="changed" content="2022-08-31T08:38:58.757371449"/>
	<style type="text/css">
		@page { size: 8.5in 11in; margin: 0.79in }
		p { line-height: 115%; margin-bottom: 0.1in; background: transparent }
		a:link { color: #000080; so-language: zxx; text-decoration: underline }
	</style>
</head>
<body lang="en-US" link="#000080" vlink="#800000" dir="ltr"><p style="line-height: 100%; margin-bottom: 0in">
<i><b>Introduction</b></i></p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in">I have been using
OpenWrt for years.  It’s on all my routers except one.  It still
has Gargoyle.  I would like to switch it over to OpenWrt.  For that,
I need to be able to report daily, weekly and monthly Internet data
usage.  I also need to be able to report totals and for all or an IP
subset like the smart TVs.  Also, if usage is over a given quota, I
want to restrict the bandwidth for all or just some devices.</p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in">I have not seen any
posts here describing something like this.  I have been searching for
awhile.  So, for the Gargoyle migration I made some notes and wrote
some scripts.  I thought I would share.  Maybe someone has a similar
need.  
</p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><i><b>Data
Collection</b></i></p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in">To collect the data,
I decided on “bandwidthd-sqlite”.  It has nice graphs and I can
easily pull the details I need from the SQLite database.  
</p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in">To install, use
these commands:</p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">opkg
update; opkg </font></font><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">install
</font></font><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">bandwidth</font></font><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">d-sqlite
</font></font><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">sqlite</font></font><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">3-cli</font></font></p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in">To configure, we
need to stop the service and check the configuration.  Use the
following commands:</p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">/etc/init.d/bandwidthd
stop</font></font></p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">uci
show bandwidthd</font></font></p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in">Confirm the subnet
and interface device is correct for the router.  If needed, adjust
using commands like these:</p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">uci
set bandwidthd.@bandwidthd[0].subnets='192.168.n.0/24'</font></font></p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">uci
set bandwidthd.@bandwidthd[0].dev='br-lan'</font></font></p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">uci
commit bandwidthd</font></font></p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in">We need to fine tune
the data capture.  We just want data to/from the Internet.  For this,
we’ll need some info from the network interface.  Use this command:</p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">ifconfig
`uci get bandwidthd.@bandwidthd[0].dev`</font></font></p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in">Make note of the MAC
address and the IP address.  Edit and use the following configuration
commands:</p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">uci
set bandwidthd.@bandwidthd[0].filter='ip and ether host
xx:xx:xx:xx:xx:xx and not host 192.168.n.1'</font></font></p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">uci
set bandwidthd.@bandwidthd[0].promiscuous='false'</font></font></p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">uci
commit bandwidthd</font></font></p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">/etc/init.d/bandwidthd
start</font></font></p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in">The filter will tell
“bandwidthd” to only look at packets sent to/from the router but
the router was not the sender or receiver.  Basically, that’s
default route packets.</p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in">The path for the
SQLite database is actually under /tmp, so it will be lost during a
power cycle of the router.  However, we need that data.  So, use a
thumb drive to save it on a regular schedule.  Create a folder on it
called “bandwidthd” and add the following to LuCI → System →
Scheduled Tasks.  This example will run every 10 minutes.  Adjust
path and schedule as needed.  
</p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">*/10
* * * * DEST=/mnt/sda1/bandwidthd/stats.db;rm $DEST;sqlite3 `uci get
bandwidthd.@bandwidthd[0].sqlite_filename` &quot;vacuum into '$DEST'&quot;</font></font></p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in">We’ll need to put
the database file back before the service is started at boot time. 
Disable auto-start with this command:</p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">/etc/init.d/bandwidthd
disable</font></font></p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in">Then add the
following commands via LuCI → System → Startup and select the
Local Startup tab.  Adjust the path as needed.</p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">mkdir
/tmp/bandwidthd</font></font></p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">cp
/mnt/sda1/bandwidthd/stats.db /tmp/bandwidthd</font></font></p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">/etc/init.d/bandwidthd
start</font></font></p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="Liberation Serif, serif"><font size="2" style="font-size: 11pt"><span style="font-style: normal">T</span><span style="font-style: normal">he
database can grow quite large over time.  It should be cleaned up </span><span style="font-style: normal">on
a regular basis.  The following commands can be used to clean it of
older records not needed any more.  This example keeps totals for 26
weeks and details for 8 weeks.  The commands can be placed in a
script and scheduled to run weekly.</span></font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">TOTALWEEKS=26</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">DETAILWEEKS=8</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">NOWTS=`date
'+%s'`</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">TOTALTS=$((NOWTS
- TOTALWEEKS * 7 * 24 * 60 * 60))</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">DETAILTS=$((NOWTS
- DETAILWEEKS * 7 * 24 * 60 * 60))</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">DB=`uci
get bandwidthd.@bandwidthd[0].sqlite_filename`</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">sqlite3
$DB 'DELETE FROM bd_rx_log WHERE timestamp &lt; $DETAILTS;'</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">sqlite3
$DB 'DELETE FROM bd_tx_log WHERE timestamp &lt; $DETAILTS;'</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">sqlite3
$DB 'DELETE FROM bd_rx_total_log WHERE timestamp &lt; $TOTALTS;'</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">sqlite3
$DB 'DELETE FROM bd_tx_total_log WHERE timestamp &lt; $TOTALTS;'</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><i><b>Reporting</b></i></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><span style="font-style: normal">To
view the data as charts, use the IP address of your router and </span><span style="font-style: normal">append
“/</span><span style="font-style: normal">bandwidthd” to it.  It
will be something like <a href="http://192.168.188.1/bandwidthd">http://192.168.</a></span><a href="http://192.168.188.1/bandwidthd"><span style="font-style: normal">1</span></a><span style="font-style: normal"><a href="http://192.168.188.1/bandwidthd">.1/bandwidthd</a>.
 </span>
</p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><span style="font-style: normal">Note:
The data for the charts does not come from the database.  So, after a
power cycle, the charts will be missing </span><span style="font-style: normal">older
</span><span style="font-style: normal">data.  However, the attached
script “bandwidth_used.sh” </span><span style="font-style: normal">will</span><span style="font-style: normal">
query the database </span><span style="font-style: normal">that
contains all the data</span><span style="font-style: normal">.</span></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">Syntax
is: bandwidth_used.sh [arguments]</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">Arguments
are as follows:</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in">
 <font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">-d
--daily         Turnover is daily.  Default.</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in">
 <font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">-w
--weekly[=n]    Turnover is weekly.  Default is Sat(0).</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in">
 <font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">-m
--monthly[=n]   Turnover is monthly. For day of month, use n. Default
is first(1).</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in">
 <font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">-h
--hour=n        Turnover hour, 00-23.  Default is 12.</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in">
 <font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">-s
--spans=n       Look back this many turnover spans.  Default is 10.</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in">
 <font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">-b
--bytes=x       Scale the bytes, k, m or g.  Default is Kbytes.</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in">
 <font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">-q
--quota=x       Report % of quota.  Also, return non zero if current
span over quota.  Default 1 Tbytes.</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in">
 <font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">-x
--exclude=s     Exclude comma separated list of dotted IP addresses
from total in report.</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in">
 <font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">-i
--include=s     Include only comma separated list of dotted IP
addresses in report.</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in">
 <font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">-n
--note=s        Include short note on the report title.</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><span style="font-style: normal">For
example, to query the daily </span><span style="font-style: normal">6
AM </span><span style="font-style: normal">usage of the smart TV at
192.168.1.76, </span><span style="font-style: normal">with a quota of
8 Gbytes, </span><span style="font-style: normal">use this command:</span></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt"><span style="font-style: normal">./bandwidth_used.sh
--note=TV --hour=06 --bytes=m --include=192.168.</span><span style="font-style: normal">1.76</span><span style="font-style: normal">
--quota=8192</span></font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">Bandwidth
Quota Daily TV Report for: 2022-28-29 15:28</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">Time
span (from - to)	Total	Bytes	% of 8192 Mbytes</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">2022-08-29
06:00 - 2022-08-30 06:00	221	Mbytes	2%</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">2022-08-28
06:00 - 2022-08-29 06:00	6074	Mbytes	74%</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">2022-08-27
06:00 - 2022-08-28 06:00	0	Mbytes	0%</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">2022-08-26
06:00 - 2022-08-27 06:00	839	Mbytes	10%</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">2022-08-25
06:00 - 2022-08-26 06:00	3501	Mbytes	42%</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">2022-08-24
06:00 - 2022-08-25 06:00	7696	Mbytes	93%</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">2022-08-23
06:00 - 2022-08-24 06:00	0	Mbytes	0%</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">2022-08-22
06:00 - 2022-08-23 06:00	0	Mbytes	0%</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">2022-08-21
06:00 - 2022-08-22 06:00	0	Mbytes	0%</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">2022-08-20
06:00 - 2022-08-21 06:00	0	Mbytes	0%</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in">To
convert the report to HTML, pipe the report to the following awk
command:</p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt"><span style="font-style: normal">awk
-F '\t' 'BEGIN { print &quot;&lt;!DOCTYPE html&gt;&lt;html&gt;&lt;body&gt;&lt;table&gt;&quot;
}</span><span style="font-style: normal">\</span></font></font></p>
<p style="line-height: 100%; margin-bottom: 0in">  <font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt"><span style="font-style: normal">{
if (substr($1,1,9) == &quot;Bandwidth&quot;)</span><span style="font-style: normal">\</span></font></font></p>
<p style="line-height: 100%; margin-bottom: 0in">  <font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt"><span style="font-style: normal">{
print &quot;&lt;tr&gt;&lt;td colspan='4' align='center'&gt;&lt;b&gt;&lt;h3&gt;&quot;
$1 &quot;&lt;/h3&gt;&lt;/b&gt;&lt;/td&gt;&lt;/tr&gt;&quot;} else</span><span style="font-style: normal">\</span></font></font></p>
<p style="line-height: 100%; margin-bottom: 0in">  <font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt"><span style="font-style: normal">{
print &quot;&lt;tr&gt;&lt;td&gt;&quot; $1 &quot;&lt;/td&gt;&lt;td
align='right'&gt;&quot; $2 &quot;&lt;/td&gt;&lt;td&gt;&quot; $3</span><span style="font-style: normal">\</span></font></font></p>
<p style="line-height: 100%; margin-bottom: 0in">    <font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt"><span style="font-style: normal">&quot;&lt;/td&gt;&lt;td
align='right'&gt;&quot; $4 &quot;&lt;/td&gt;&lt;/tr&gt;&quot;} } END
{ print &quot;&lt;/table&gt;&lt;/body&gt;&lt;/html&gt;&quot; }'</span></font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="font-style: normal; font-weight: normal; line-height: 100%; margin-bottom: 0in">
I use the HTML version of the reports for a custom page under
/www/bandwidthd and for emails.  
</p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><i><b>Traffic
Shaping</b></i></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><span style="font-style: normal">The
“</span><span style="font-style: normal">bandwidth_used.sh”
</span><span style="font-style: normal">returns an error code of 250
if the current time span, first row of the report, is 100% or more. 
</span><span style="font-style: normal">It </span><span style="font-style: normal">can
be used to trigger another script.  </span><span style="font-style: normal">The
triggered script could, f</span><span style="font-style: normal">or
example, </span><span style="font-style: normal">perform traffic
shaping so as to limit the data usage for some or all devices.  </span>
</p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><span style="font-style: normal">The
attached “bandwidth_shape.sh” script uses qdisc CAKE to limit the
upload and download </span><span style="font-style: normal">speed</span><span style="font-style: normal">.
 </span><span style="font-style: normal">It needs the traffic control
package</span><span style="font-style: normal">s</span><span style="font-style: normal">.
 Use this command </span><span style="font-style: normal">to install
them</span><span style="font-style: normal">:</span></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">opkg
update; opkg </font></font><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">install
tc-full kmod-ifb </font></font><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">kmod-sched-</font></font><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">cake</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="Liberation Serif, serif"><font size="2" style="font-size: 10pt">Details
of the script are as follows:</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">Syntax
is: bandwidth_shape.sh start | stop [arguments]</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">Arguments
are as follows:</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in">
 <font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">start
| stop       Start or stop traffic shaping.  Required.</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in">
 <font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">-d
--download=nbit Download speed in bits/s.  Default is 1Mbit.</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in">
 <font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">-u
--upload=nbit   Upload speed in bits/s.  Default is 500Kbit.</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in">
 <font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">-x
--exclude=s     Exclude comma separated list of dotted IP addresses
from traffic shaping.</font></font></p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in">
 <font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt">-i
--include=s     Include only comma separated list of dotted IP
addresses in traffic shaping. </font></font>
</p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in">For
example, to shape the data usage for the smart TV to the defaults,
forcing it to standard definition, use the following command:</p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="DejaVu Sans Mono, monospace"><font size="2" style="font-size: 9pt"><span style="font-style: normal">./bandwidth_shape.sh
</span><span style="font-style: normal">start </span><span style="font-style: normal">--include=192.168.</span><span style="font-style: normal">1.76</span><span style="font-style: normal">
</span></font></font>
</p>
<p style="font-style: normal; line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="Liberation Serif, serif"><font size="2" style="font-size: 11pt"><i><b>Summary</b></i></font></font></p>
<p style="line-height: 100%; margin-bottom: 0in"><br/>

</p>
<p style="line-height: 100%; margin-bottom: 0in"><font face="Liberation Serif, serif"><font size="2" style="font-size: 11pt"><span style="font-style: normal">I
hope others find this useful.  I have tested these procedures and
scripts on OpenW</span></font></font><font face="Liberation Serif, serif"><font size="2" style="font-size: 11pt"><span style="font-style: normal">rt</span></font></font><font face="Liberation Serif, serif"><font size="2" style="font-size: 11pt"><span style="font-style: normal">
</span></font></font><span style="font-style: normal">21.02.3</span><font face="Liberation Serif, serif"><font size="2" style="font-size: 11pt"><span style="font-style: normal">.
 I don’t know if they will work on older or future version</span></font></font><font face="Liberation Serif, serif"><font size="2" style="font-size: 11pt"><span style="font-style: normal">s</span></font></font><font face="Liberation Serif, serif"><font size="2" style="font-size: 11pt"><span style="font-style: normal">.
 Also, I want to send a big thank you out to the OpenW</span></font></font><font face="Liberation Serif, serif"><font size="2" style="font-size: 11pt"><span style="font-style: normal">rt</span></font></font><font face="Liberation Serif, serif"><font size="2" style="font-size: 11pt"><span style="font-style: normal">
team and supporters plus all the contributors on the forms for all
their hard work on the awesome open source project called OpenW</span></font></font><font face="Liberation Serif, serif"><font size="2" style="font-size: 11pt"><span style="font-style: normal">rt</span></font></font><font face="Liberation Serif, serif"><font size="2" style="font-size: 11pt"><span style="font-style: normal">.
 </span></font></font>
</p>
</body>
</html>
