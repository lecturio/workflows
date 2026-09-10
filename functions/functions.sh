#!/bin/bash
# Function namespace

source $WF_DIR/functions/connectivity.sh
source $WF_DIR/functions/execution.sh
source $WF_DIR/functions/branches.sh

COMMANDS=( "in-progress" "to-staging" "resolved" "deployable" "closed" "pr" )

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

	require_safe_branch_name "$WF_TASK" "WF_TASK"
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

#
# Prefixes every line, not just the first: the git output that reaches here
# through emit_failonerror is several lines of reason and advice, and the tail
# of it used to come out bare, reading as if the tool had stopped talking
# mid-message.
#
function print_err() {
	local line
	while IFS= read -r line; do
		echo "[ERROR] $line"
	done <<< "$1"
}

#
# Reject names that would break unquoted eval in emit() or be parsed as git options.
# Must start with a letter or digit (no leading - or +). - is first in the class so it is literal.
# $1 - branch name
# $2 - label for the error (e.g. WF_TASK, WF_PROD_BRANCH)
#
function require_safe_branch_name() {
	if [[ ! "$1" =~ ^[A-Za-z0-9][-A-Za-z0-9._/]*$ ]]; then
		WF_STATUS=1
		print_err "Invalid branch name for $2: $1"
		print_build_msg
		exit 1
	fi
}

#
# Trim leading and trailing whitespace.
# $1 - string
#
function trim_whitespace() {
	local s="$1"
	s="${s#"${s%%[![:space:]]*}"}"
	s="${s%"${s##*[![:space:]]}"}"
	printf '%s' "$s"
}

#
# Percent-encode a git ref for a GitHub compare URL (so / becomes %2F).
# $1 - branch name
#
function github_ref_encode() {
	local s="$1" out="" i c hex
	local LC_ALL=C
	for (( i = 0; i < ${#s}; i++ )); do
		c="${s:i:1}"
		case "$c" in
			[A-Za-z0-9._~-]) out+="$c" ;;
			*)
				printf -v hex '%02X' "'$c"
				out+="%$hex"
				;;
		esac
	done
	printf '%s' "$out"
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
		value="$(trim_whitespace "${BASH_REMATCH[2]}")"
		if [[ "$value" =~ ^\"(.*)\"$ ]]; then
			value="$(trim_whitespace "${BASH_REMATCH[1]}")"
		elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
			value="$(trim_whitespace "${BASH_REMATCH[1]}")"
		fi

		case "$key" in
			WF_PROD_BRANCH|WF_STAGING_BRANCH)
				require_safe_branch_name "$value" "$key"
				export "$key=$value"
				;;
			*)
				print_msg "Unrecognized key in .gitflow: $key"
				;;
		esac
	done < "$GITFLOW_FILE"
}

#
# Update origin and drop stale remote-tracking branches.
#
function refresh_origin() {
	emit "git fetch" quiet
	emit "git remote prune origin" quiet
}

#
# Fail when a configured branch is missing on origin.
# $1 - branch name
#
function require_origin_branch() {
	local branch="$1"
	require_safe_branch_name "$branch" "origin branch"
	emit "git rev-parse --verify --quiet origin/$branch" quiet
	if [ $? -ne 0 ]; then
		WF_STATUS=1
		print_err "Configured branch origin/$branch does not exist"
		print_build_msg
		exit 1
	fi
}

#
# "self" is reserved in the ticket slot: it addresses the tool itself, never a
# ticket. Called before check_update and before the project-clone check, and
# always exits.
#
function handle_self_command() {
	if [ "$WF_COMMAND" != "update" ] || [ -n "$WF_ENV" ]; then
		WF_STATUS=1
		print_err "\"self\" is a reserved word and can only be used as: gitflow self update"
		print_build_msg
		exit 1
	fi

	if ! cd "$WF_DIR"; then
		WF_STATUS=1
		print_err "Could not enter the tool clone at $WF_DIR"
		print_build_msg
		exit 1
	fi

	print_msg "Updating $WF_DIR"
	emit "git pull --rebase"
	if [ $? -gt 0 ]; then
		WF_STATUS=1
		print_build_msg
		exit 1
	fi

	local UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
	local AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null)
	if [ "${AHEAD:-0}" -gt 0 ]; then
		print_msg "$AHEAD local commit(s) not on ${UPSTREAM:-upstream} - push or drop them or the update check keeps failing"
	fi

	print_build_msg
	exit 0
}
