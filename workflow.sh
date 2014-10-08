#!/bin/bash

# Entry point for workflow
export WF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

INSTALLED=`readlink /usr/local/bin/gitflow`
if [ $INSTALLED != "" ]; then
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

WF_TASK=`echo $WF_TASK | sed '$s/origin\///'`

source $WF_DIR/config.sh
source $WF_DIR/functions/functions.sh

cd $WF_DIR
check_update
validate_input_params

out=$(check_github)
if [ $? -gt 1 ]; then
	echo $out
	echo "Add your private key ssh-add [path to pk]."
	exit 1
fi

cd $WF_PROJECT_ROOT
#TODO if is missing - clone it

print_msg "Scanning for tasks..."
print_msg - line

# global options support
for i in "$@"
do
case $i in
    -m*|--message*)
    MESSAGE="${@##*-m}"
    ;;
    *)
            # unknown option
    ;;
esac
done

MESSAGE=$(echo $MESSAGE | sed '$s/'$WF_TASK' resolved sync //')

source $WF_DIR/commands/${WF_COMMAND}.sh
if [[ "$WF_COMMAND" == "resolved" && "$WF_ENV" == "sync" ]]; then
	source $WF_DIR/commands/${WF_COMMAND}-${WF_ENV}.sh
fi
print_build_msg
