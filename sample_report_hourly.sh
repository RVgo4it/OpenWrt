#!/bin/sh

# This sample script will generate a custom report for daily, weekly and monthly quotas.  
# It will also limit bandwidth if daily TV or weekly quotas exceeded.   
# It assumes the bandwidth_used.sh and bandwidth_shape.sh were downloaded to /root.

# Smart TVs and Chromecasts
TVS=192.168.1.154,192.168.1.151,192.168.1.38,192.168.1.187
# VoIP phone
VOIP=192.168.1.22

# Make sure we are few seconds into the time span
sleep 5

# Get daily quota report for daily TVs; 30gb, cutover 5am
/root/bandwidth_used.sh -b=g -q=30 -i=$TVS -n=TV -h=05 > /tmp/bandwidth_rpt.txt
RETD=$?
echo Daily Return: $RETD

# Get weekly quota report for all; 300gb, cutover sat noon, show just 8 weeks
/root/bandwidth_used.sh -s=8 -w -b=g -q=300 -n=Total >> /tmp/bandwidth_rpt.txt
RETW=$?
echo Weekly Return: $RETW

# Get monthly quota report for all; 1tb, cutover 1st midnight, show just 2 months
/root/bandwidth_used.sh -s=2 -m -b=g -n=Mediacom -h=00 >> /tmp/bandwidth_rpt.txt

# Create the html file custom report.  Visible at http://192.168.1.1/bandwidthd/quota.html
awk -F '\t' 'BEGIN { print "<!DOCTYPE html><html><head><title>Bandwidth Quota Report</title></head><body><table>" }\
  { if (substr($1,1,9) == "Bandwidth")\
    { print "<tr><td colspan='4' align='center'><b><h3>" $1 "</h3></b></td></tr>"}\
  else\
    { print "<tr><td>" $1 "</td><td align='right'>" $2 "</td><td>" $3 "</td><td align='right'>" $4 "</td></tr>"} }\
  END { print "</table></body></html>" }' /tmp/bandwidth_rpt.txt > /www/bandwidthd/quota.html

# Turn off traffic shaping if any
/root/bandwidth_shape.sh stop

# Weekly over quota?
if [[ $RETW -eq 250 ]]; then 
  # Limit all except the VoIP phone 
  /root/bandwidth_shape.sh start -x=$VOIP
# daily over quota?
elif [[ $RETD -eq 250 ]]; then
  # Limit just the TVs
  /root/bandwidth_shape.sh start -i=$TVS
fi
