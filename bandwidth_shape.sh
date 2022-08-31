#!/bin/sh

# ref: https://github.com/lynxthecat/cake-dual-ifb
# packages tc-full kmod-ifb kmod-sched-cake required

DEV=`uci get bandwidthd.@bandwidthd[0].dev`
BWIPSACT=X
BWIPS=
BWSUBNET=`uci get bandwidthd.@bandwidthd[0].subnets`
BWUP=500Kbit
BWDOWN=1Mbit
BWACT=
BWFLAG=/tmp/bandwidth_shape

for P in "$@"; do                                                                                                                                                     
  set -- ${P//=/ }                                                                                                                                                  
  case $1 in                                                                                                                                                        
    "-d" | "--download")                                                                                                                                               
      BWDOWN=$2                                                                                                                                                         
    ;;                                                                                                                                                              
    "start" | "stop")                                                                                                                           
      BWACT=$1
    ;;
    "-u" | "--upload")                                                                                                                           
      BWUP=$2                                                                                                                                    
    ;;
    "-x" | "--exclude")                                                                                                                                             
      BWIPSACT=X                                                                                                                                                       
      BWIPS=$2                                                                                                                                                  
    ;;                                                                                                                                                              
    "-i" | "--include")                                                                                                                                             
      BWIPSACT=I                                                                                                                                                       
      BWIPS=$2                                                                                                                                                  
    ;;
    *)                                                                                                                                                              
      echo "Syntax Error: Arguments are as follows:"                                                                                                                
      echo "  start | stop       Start or stop traffic shaping.  Required."
      echo "  -d --download=nbit Download speed in bits/s.  Default is 1Mbit."                                                                                                      
      echo "  -u --upload=nbit   Upload speed in bits/s.  Default is 500Kbit."                                                                                           
      echo "  -x --exclude=s     Exclude comma separated list of dotted IP addresses from traffic shaping."                                                         
      echo "  -i --include=s     Include only comma separated list of dotted IP addresses in traffic shaping."                                                               
      exit 0                                                                                                                                                        
    ;;                                                                                                                                                              
  esac                                                                                                                                                              
done

if [[ "$BWACT" == "start" ]] ; then 

  # check if already done                                                                                     
  if [[ -e $BWFLAG ]] ; then                                                                                  
    echo Already started                                                                                      
    exit 1                                                                                                    
  fi                                                                                                          
  touch $BWFLAG 

  # ifb interfaces for handling ingress on WAN 
  ip link add name ifb-ul type ifb
  ip link add name ifb-dl type ifb
  ip link set ifb-ul up
  ip link set ifb-dl up

  tc qdisc add dev $DEV handle ffff: ingress
  tc qdisc add dev $DEV handle 1: root cake

  # apply CAKE on the ifbs
  tc qdisc add dev ifb-dl root cake bandwidth $BWDOWN diffserv4 egress  overhead 92
  tc qdisc add dev ifb-ul root cake bandwidth $BWUP   diffserv4 ingress overhead 92

  # capture upload (ingress) on $DEV 
  # pass(ignore) on local traffic
  tc filter add dev $DEV parent ffff: protocol ip prio 1 u32 match ip dst $BWSUBNET match ip src $BWSUBNET action pass
  # pass(ignore) on bcast/mcast
  tc filter add dev $DEV parent ffff: protocol ip prio 3 u32 match u8 0x01 0x01 at 0 match u8 0xe0 0xe0 at 16 action pass
  P=10
  IFS=,
  for BWIP in $BWIPS; do
    unset IFS
    [[ $BWIPSACT == I ]] && tc filter add dev $DEV parent ffff: protocol ip prio $P u32 match ip src $BWIP action mirred egress redirect dev ifb-ul
    [[ $BWIPSACT == X ]] && tc filter add dev $DEV parent ffff: protocol ip prio $P u32 match ip src $BWIP action pass
    P=$((P+1))
  done
  [[ $BWIPSACT == X ]] && tc filter add dev $DEV parent ffff: protocol ip prio $P u32 match ip src $BWSUBNET action mirred egress redirect dev ifb-ul

  # capture download (egress) on $DEV 
  # pass(ignore) on local traffic
  tc filter add dev $DEV parent 1: protocol ip prio 1 u32 match ip src $BWSUBNET match ip dst $BWSUBNET action pass
  # pass(ignore) on bcast/mcast
  tc filter add dev $DEV parent 1: protocol ip prio 3 u32 match u8 0x01 0x01 at 0 match u8 0xe0 0xe0 at 16 action pass 
  P=10
  IFS=,
  for BWIP in $BWIPS; do
    unset IFS
    [[ $BWIPSACT == I ]] && tc filter add dev $DEV parent 1: protocol ip prio $P u32 match ip dst $BWIP action mirred egress redirect dev ifb-dl
    [[ $BWIPSACT == X ]] && tc filter add dev $DEV parent 1: protocol ip prio $P u32 match ip dst $BWIP action pass
    P=$((P+1))
  done
  [[ $BWIPSACT == X ]] && tc filter add dev $DEV parent 1: protocol ip prio $P u32 match ip dst $BWSUBNET action mirred egress redirect dev ifb-dl 

  tc -s -d filter show dev $DEV parent 1:
  tc -s -d filter show dev $DEV parent ffff:
  tc -s qdisc show dev ifb-ul
  tc -s qdisc show dev ifb-dl

fi

if [[ "$BWACT" == "stop" ]] ; then 

  # check if already done                                                                                                                            
  if [[ ! -e $BWFLAG ]] ; then                                                                                                                       
    echo Not started.                                                                                                                                
    exit 1                                                                                                                                           
  fi                                                                                                                                                 
  rm $BWFLAG

  # remove the qdiscs
  tc qdisc del dev $DEV ingress
  tc qdisc del dev $DEV root
  tc qdisc del dev ifb-ul root
  tc qdisc del dev ifb-dl root

  # remove the interfaces
  ip link set ifb-ul down
  ip link del ifb-ul
  ip link set ifb-dl down
  ip link del ifb-dl

fi


