#!/bin/bash

# Entry point for workflow
export WF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

INSTALLED=`readlink /usr/local/bin/gitflow`
if [ "$INSTALLED" != "" ]; then
	export WF_DIR=`dirname $INSTALLED`
fi

# Setup auto completion
STARTUP_SCRIPT=~/.profile
if [ Linux = "$(uname)" ]; then
	STARTUP_SCRIPT=~/.bashrc
fi

if [[ ! -f $STARTUP_SCRIPT ||
	`cat $STARTUP_SCRIPT | grep $WF_DIR/gitflow-completion.sh` == "" ]]; then
	echo >> $STARTUP_SCRIPT
	echo "if [ -f $WF_DIR/gitflow-completion.sh ]; then" >> $STARTUP_SCRIPT
	echo -e "\t. $WF_DIR/gitflow-completion.sh" >> $STARTUP_SCRIPT
	echo fi >> $STARTUP_SCRIPT
	. $STARTUP_SCRIPT
fi

# export parameters
export WF_TASK=$1
export WF_COMMAND=$2
export WF_ENV=$3
export WF_STATUS=0

WF_TASK=$(printf '%s' "$WF_TASK" | sed 's|^origin/||')
WF_GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

source $WF_DIR/functions/functions.sh

# "self" is a reserved word in the ticket slot - it addresses the tool itself,
# so it runs before the update check and without needing a project clone
if [ "$WF_TASK" == "self" ]; then
	handle_self_command
fi

if [ -z "$WF_GIT_ROOT" ]; then
	print_err "gitflow must be run inside a project clone"
	exit 1
fi

cd $WF_DIR
check_update
validate_input_params

out=$(check_github)
if [ $? -gt 1 ]; then
	echo $out
	echo "Add your private key ssh-add [path to pk]."
	exit 1
fi

cd "$WF_GIT_ROOT"

WF_REPO=$(git config --get remote.origin.url)
if [ -z "$WF_REPO" ]; then
	print_err "Could not read origin URL from the current repository"
	exit 1
fi
export WF_REPO

load_gitflow "$WF_GIT_ROOT/.gitflow"
: "${WF_PROD_BRANCH:=master}"
: "${WF_STAGING_BRANCH:=staging}"
require_safe_branch_name "$WF_PROD_BRANCH" "WF_PROD_BRANCH"
require_safe_branch_name "$WF_STAGING_BRANCH" "WF_STAGING_BRANCH"
export WF_PROD_BRANCH
export WF_STAGING_BRANCH

print_msg "Scanning for tasks..."
print_msg - line

# global options support: -m "message", -m"message", --message "message",
# --message=message, and the unquoted -m message with the words after it
MESSAGE=""
ARGS=("$@")
for (( i = 0; i < ${#ARGS[@]}; i++ ))
do
case "${ARGS[i]}" in
	-m|--message)
	MESSAGE="${ARGS[*]:i+1}"
	break
	;;
	--message=*)
	MESSAGE="${ARGS[i]#--message=}"
	break
	;;
	-m*)
	MESSAGE="${ARGS[i]#-m}"
	break
	;;
	*)
		# unknown option
	;;
esac
done

source $WF_DIR/commands/${WF_COMMAND}.sh
if [[ "$WF_COMMAND" == "resolved" && "$WF_ENV" == "sync" ]]; then
	source $WF_DIR/commands/${WF_COMMAND}-${WF_ENV}.sh
fi
print_build_msg
