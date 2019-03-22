#!/bin/bash

#REQUIRE rsvp, rCommand and rCommandSu scripts to run
#USAGE: ./remote [-h\--host <host name | IP >| -l\--list <host list file>] [-c\--copy <file to be copied>] [-x\--execute | -xs\--execute_sudo <'command'>]

USAGE='./remote [-h\--host <host name | IP >| -l\--list <host list file>] [-c\--copy <file to be copied>] [-x\--execute | -xs\--execute_sudo <'command'>]'


#ARG MANAGEMENT
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
    shift # past argument
    shift # past value
    ;;
    -x|--execute)
    if [ ! -z $2 ]; then
    	COMMAND="$2"
    	shift # past argument
    else
	SSH=1
    fi
    shift # past value
    ;;
    -xs|--execute_sudo)
    ROOT=1
    if [ ! -z $2 ]; then
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

SSH_USER=<>
PASS=<>


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



for i in "${HOST_ARRAY[@]}"
do
	
	if [ ! -z $SCP_FILE ]; then
		./rscp $i $SCP_FILE $SSH_USER $PASS
	fi

	if [ ! -z $COMMAND ]; then
		if [ ! -z $ROOT ]; then
			./rCommandSu $i $COMMAND $SSH_USER $PASS 1 0
		else
			./rCommandSu $i $COMMAND $SSH_USER $PASS 0 0
		fi
	elif [ ! -z $SSH ]; then
		if [ ! -z $ROOT ]; then
			./rCommandSu $i "dummy" $SSH_USER $PASS 1 1
		else
			./rCommandSu $i "dummy" $SSH_USER $PASS 0 1
		fi
	fi

	

done
