#!/bin/bash
# Function namespace

source $WF_DIR/functions/connectivity.sh
source $WF_DIR/functions/execution.sh

COMMANDS=( "in-progress" "resolved" "deployable" "closed" "pr" )

#
# Validation of input parameters
#
function validate_input_params() {
	if [[ -z $WF_TASK || -z $WF_COMMAND ]]; then
		echo "Provide parameters: gitflow JIRA-001 in-progress"
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

		if [ -t 0 ]; then
			let "width=$(stty size | cut -d ' ' -f 2) - 7"
		else
			let "width=${COLUMNS:-80} - 7"
		fi
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

#
# Parse repo-level .gitflow (dotenv KEY=value).
# $1 - path to .gitflow
#
function load_gitflow() {
	local GITFLOW_FILE="$1"
	if [ ! -f "$GITFLOW_FILE" ]; then
		return 0
	fi

	local line key value
	while IFS= read -r line || [ -n "$line" ]; do
		line="${line%$'\r'}"
		[[ "$line" =~ ^[[:space:]]*$ ]] && continue
		[[ "$line" =~ ^[[:space:]]*# ]] && continue

		if [[ ! "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
			print_msg "Ignoring invalid line in .gitflow: $line"
			continue
		fi

		key="${BASH_REMATCH[1]}"
		value="${BASH_REMATCH[2]}"
		if [[ "$value" =~ ^\"(.*)\"$ ]]; then
			value="${BASH_REMATCH[1]}"
		elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
			value="${BASH_REMATCH[1]}"
		fi

		case "$key" in
			WF_PROD_BRANCH|WF_STAGING_BRANCH)
				export "$key=$value"
				;;
			*)
				print_msg "Unrecognized key in .gitflow: $key"
				;;
		esac
	done < "$GITFLOW_FILE"
}

#
# Fail when a configured branch is missing on origin.
# $1 - branch name
#
function require_origin_branch() {
	emit "git rev-parse --verify --quiet origin/$1" quiet
	if [ $? -ne 0 ]; then
		print_err "Configured branch origin/$1 does not exist"
		print_build_msg
		exit 1
	fi
}
