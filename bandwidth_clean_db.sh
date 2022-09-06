#! /bin/sh
# Cron job to clean up the database
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