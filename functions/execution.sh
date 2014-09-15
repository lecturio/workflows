#!/bin/bash

#
# executes specific command
# $1 - bash command to execute
# $2 - debug $1 (just print it)
#
function emit() {
	if [[ $WF_DEBUG -eq 1 || "$2" == "debug" ]]; then
		echo -n "info>>> "
		echo "$1 <<<"
	else
		if [ "$2" == "quiet" ]; then
			out=$(eval "$1" 2>&1)
		else
			out=$(eval "$1" 2>&1)
			print_msg "$out"

		fi
	fi
}
