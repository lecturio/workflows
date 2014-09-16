#!/bin/bash

# Entry point for workflow

export WF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WF_TASK=$1
export WF_COMMAND=$2
export WF_ENV=$3
export WF_STATUS=0

source $WF_DIR/config.sh
source $WF_DIR/functions/functions.sh

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

for i in "$@"
do
case $i in
    -m=*|--message=*)
    MESSAGE="${i#*=}"

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
