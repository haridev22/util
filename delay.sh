#!/bin/bash

#USAGE: ./delay [-i\--ip <ip/host>] -d|--delay <delay> [-t|--timeout <timeout>]

USAGE='./delay [-i\--ip <ip/host>] -d|--delay <delay> [-t|--timeout <timeout>]'

function reset_delay()
{
	local TO=$1
	sleep $TO
	echo "Delay reset"
	tc qdisc del dev eth0 root
}


function valid_ip()
{
	local  ip=$1
	local  stat=1

	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        	OIFS=$IFS
        	IFS='.'
        	ip=($ip)
        	IFS=$OIFS
        	[[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
        	    && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        	stat=$?
    	fi
    	return $stat
}

#ARG MANAGEMENT
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -i|--ip)
    INPUT_IP="$2"
    shift # past argument
    shift # past value
    ;;
    -t|--timeout)
    TIMEOUT="$2"
    shift # past argument
    shift # past value
    ;;
    -d|--delay)
    DELAY="$2"
    shift # past argument
    shift # past value
    ;;
    --default)
    DEFAULT=YES
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters
if [[ -n $1 ]];then
	echo "Unknown arguments. $USAGE"
	exit
fi


if [ ! -z INPUT_IP ] && [ valid_ip $INPUT_IP]; then
	IP=$INPUT_IP
else
	IP=`getent hosts $INPUT_IP | awk '{ print $1 }'`
fi

if [ ! -z $DELAY ]; then
	if [ ! -z $IP ]; then 
		tc qdisc del dev eth0 root
		tc qdisc add dev eth0 root handle 1: prio
		tc qdisc add dev eth0 parent 1:3 handle 30: tbf rate 20kbit buffer 1600 limit  3000
		tc qdisc add dev eth0 parent 30:1 handle 31: netem  delay $DELAY 10ms distribution normal
		tc filter add dev eth0 protocol ip parent 1:0 prio 3 u32 match ip dst $IP  flowid 1:3
	else
		tc qdisc add dev eth0 root netem delay $DELAY
	fi
fi
if [ ! -z "$TIMEOUT" ]; then
	reset_delay $TIMEOUT &
fi
