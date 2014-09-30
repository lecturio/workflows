#!/bin/bash
# Function namespace

source $WF_DIR/functions/connectivity.sh
source $WF_DIR/functions/execution.sh

COMMANDS=( "in-progress" "resolved" "deployable" "closed" )

#
# Validation of input parameters
#
function validate_input_params() {
	if [[ -z $WF_TASK || -z $WF_COMMAND ]]; then
		echo "Provide parameters: ./worflow.sh JIRA-001 in-progress"
		echo "feature name (required)"
		echo "goal (required)"
		echo "option (optional for goal)"
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

#TODO format properly multi-lines output
function print_msg() {
	if [ "$2" == "line" ]; then
		echo -n "[INFO] "
		if [ "`which stty`" != "" ]; then
			let "width=$(stty size | cut -d ' ' -f 2) - 7"
			for i in $(seq $width) 
			do
				echo -n $1
			done
			echo
		fi
	elif [ "$2" == "error" ]; then
		echo "[ERROR] $1"
	else 
		echo "[INFO] $1"
	fi
}

function print_err() {
	echo "[ERROR] $1"
}

function print_build_msg() {
	print_msg - line
	if [ $WF_STATUS -eq 0 ]; then
		print_msg "BUILD SUCCESS"
	else
		print_msg "BUILD FAILURE"
	fi
	print_msg - line
}
