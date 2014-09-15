#!/bin/bash
# Function namespace

source $WF_DIR/functions/connectivity.sh
source $WF_DIR/functions/execution.sh

COMMANDS=( "in-progress" "resolved" "deployable" )

#
# Validation of input parameters
#
function validate_input_params() {
	if [[ -z $WF_TASK || -z $WF_COMMAND ]]; then
		echo "Provide parameters: ./worflow.sh JIRA-001 in-progress"
		echo "jira task id (required)"
		echo "command (required)"
		echo "environment (optional)"
		exit 1
	fi

	VALID_CMD=0
	for CMD in "${COMMANDS[@]}"
	do
		if [ "$CMD" == "$WF_COMMAND" ]; then
			VALID_CMD=1
		fi
	done

	if [ $VALID_CMD -eq 0 ]; then
		echo -n "Available commands are: "
		for CMD in "${COMMANDS[@]}"
		do
			echo -n $CMD" "
		done
		echo 
		exit 1 
	fi


}

function print_msg() {
	if [ "$2" == "line" ]; then

		let "width=$(stty size | cut -d ' ' -f 2) - 7"
		echo -n "[INFO] "
		for i in $(seq $width) 
		do
   			echo -n $1
		done
		echo
	elif [ "$2" == "error" ]; then
		echo "[ERROR] $1"
	else 
		echo "[INFO] $1"
	fi
}
