#!/bin/bash

#REQUIRE rsvp and rCommandSu scripts to run
#USAGE: ./remote [-h\--host <host name | IP >| -l\--list <host list file>] [-c\--copy <file to be copied>] [-x\--execute | -xs\--execute_sudo <'command'>]

#Get bastion host based on the target ENV
get_env() {
        target_host=$1
        IFS='.' tokens=( $target_host )
        echo ${tokens[1]}
}
get_bastion_host() {
        env=$(echo $(get_env $1) | cut -c1-3)
        case $env in
                sea | dva | bfi | dvb )
                        echo "bulwark02.dva400.service-now.com" ;;
                tsa )
                        echo "bulwark02.tsa400.service-now.com" ;;
                tsb )
                        echo "bulwark02.tsb400.service-now.com" ;;
                ifa )
                        echo "bulwark01.ifa400.service-now.com" ;;
                ifb )
                        echo "bulwark01.ifb400.service-now.com" ;;
                ytz )
                        echo "bulwark02.ytz0.service-now.com" ;;
                ycg )
                        echo "bulwark02.ycg0.service-now.com" ;;
                syd )
                        echo "bulwark01.syd100.service-now.com" ;;
		*)
			echo "null"
        esac
}


USAGE='./remote [-h\--host <host name | IP >| -l\--list <host list file>] [-c\--copy <file to be copied>] [-x\--execute | -xs\--execute_sudo <'command'>]'


#ARG MANAGEMENT
if [ $# -eq 0 ]
  then
    echo $USAGE
fi

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -h|--host)
    REMOTE_HOST="$2"
    shift # past argument
    shift # past value
    ;;
    -l|--list)
    HOST_LIST="$2"
    shift # past argument
    shift # past value
    ;;
    -c|--copy)
    SCP_FILE="$2"
    tar -cvf scp.tar $SCP_FILE
    SCP_FILE="scp.tar"
    shift # past argument
    shift # past value
    ;;
    -x|--execute)
    if [ ! -z "$2" ]; then
    	COMMAND="$2"
    	shift # past argument
    else
	SSH=1
    fi
    shift # past value
    ;;
    -xs|--execute_sudo)
    ROOT=1
    if [ ! -z "$2" ]; then
    	COMMAND="$2"
    	shift # past argument
    else
	SSH=1
    fi
    shift # past value
    ;;
    --default)
    DEFAULT=YES
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    DEFAULT=YES
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters
if [ ! -z $DEFAULT ]; then
	echo "Unknown arguments. $USAGE"
	exit
fi

SSH_USER=har.sampathnarayanan
PASS=pass


HOST_ARRAY=()
if [ ! -z $HOST_LIST ]; then
	if [ -z $REMOTE_HOST ]; then
		while IFS= read -r line || [ -n "$line" ]; do
			HOST_ARRAY+=("$line")
		done < $HOST_LIST
	else
		echo "Incorrect arguments. Use either -h\--host or -l\--list"
	fi
	
fi

if [ ! -z $REMOTE_HOST ]; then
	if [ -z $HOST_LIST ]; then
		HOST_ARRAY+=($REMOTE_HOST)
	else
		echo "Incorrect arguments. Use either -h\--host or -l\--list"
	fi
fi



rm -f output 
x=1
for i in "${HOST_ARRAY[@]}"
do
	bastion_host=$(get_bastion_host $i)
	if [ ! -z "$SCP_FILE" ]; then
		./rscp $i "$SCP_FILE" $SSH_USER $PASS $bastion_host
	fi

	if [ ! -z "$COMMAND" ]; then
		if [ ! -z $ROOT ]; then
			nohup ./rCommandSu $i "$COMMAND" $SSH_USER $PASS 1 0 "$bastion_host" > "output$x" &
		else
			nohup ./rCommandSu $i "$COMMAND" $SSH_USER $PASS 0 0 "$bastion_host" > "output$x" &
		fi
		pids[${x}]=$!
		x=$(( $x + 1 ))
	elif [ ! -z $SSH ]; then
		if [ ! -z $ROOT ]; then
			./rCommandSu $i "dummy" $SSH_USER $PASS 1 1 "$bastion_host"
		else
			./rCommandSu $i "dummy" $SSH_USER $PASS 0 1 "$bastion_host"
		fi
	fi

done
sleep 2
if [ ! -z "$COMMAND" ]; then
	for ((i=1; i<$x; i++)); do
		tail -500f output$i | grep -v -E  '^spawn|^Last login|^All activity|bulwark|password|pbrun|#[[:space:]]*$|\$[[:space:]]*$|exit|sudo|logout|closed|^[[:space:]]*$' &
		tail_pids[${i}]=$! 
	done

	#waits for all the background process to complete
	for pid in ${pids[*]}; do
		wait $pid
	done
	echo "All Done"

	for tail_pid in ${tail_pids[*]}; do
		kill -TERM $tail_pid > /dev/null
	done
	rm -f output* 
fi
rm -f "$SCP_FILE"

