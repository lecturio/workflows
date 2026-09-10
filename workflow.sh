#!/bin/bash

# Entry point for workflow
export WF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

INSTALLED=`readlink /usr/local/bin/gitflow`
if [ "$INSTALLED" != "" ]; then
	export WF_DIR=`dirname "$INSTALLED"`
fi

# export parameters
export WF_TASK=$1
export WF_COMMAND=$2
export WF_ENV=$3
export WF_STATUS=0

WF_TASK=$(printf '%s' "$WF_TASK" | sed 's|^origin/||')
WF_GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

source "$WF_DIR/functions/functions.sh"

#
# Setup auto completion: append the loader, and leave the startup file alone
# otherwise. Sourcing it bought the shell you typed in nothing - a script
# cannot change its parent's environment - and it ran the whole of an
# interactive startup file inside the run, so a profile ending in `cd "$HOME"`
# moved the run out of the project clone and the first gitflow in a repository
# reported it was not in one. Reloading the file is yours to do, and the run
# says so.
#
STARTUP_SCRIPT=~/.profile
if [ Linux = "$(uname)" ]; then
	STARTUP_SCRIPT=~/.bashrc
fi

if [[ ! -f "$STARTUP_SCRIPT" ||
	`grep -F "$WF_DIR/gitflow-completion.sh" "$STARTUP_SCRIPT"` == "" ]]; then
	# the path is quoted inside the block too: written bare, a clone directory
	# with a space in its name left the startup file erroring on every login
	{
		echo
		echo "if [ -f \"$WF_DIR/gitflow-completion.sh\" ]; then"
		printf '\t. "%s/gitflow-completion.sh"\n' "$WF_DIR"
		echo fi
	} >> "$STARTUP_SCRIPT"
	print_msg "Tab completion added to $STARTUP_SCRIPT - reload it to use it: . $STARTUP_SCRIPT"
fi

# "self" is a reserved word in the ticket slot - it addresses the tool itself,
# so it runs before the update check and without needing a project clone
if [ "$WF_TASK" == "self" ]; then
	handle_self_command
fi

if [ -z "$WF_GIT_ROOT" ]; then
	WF_STATUS=1
	print_err "gitflow must be run inside a project clone"
	print_build_msg
	exit 1
fi

cd "$WF_DIR"
check_update
validate_input_params

#
# Where the commands that report through [INFO] and [ERROR] leave their output.
# Under $TMPDIR rather than in the tool's own directory, which is not ours to
# write in: a clone kept somewhere root-owned - which "clone somewhere
# permanent" invites - failed the redirection instead, and bash then ran no
# command at all, so every reporting stage came out as a bare [ERROR] with the
# reason it could not read. One file per run, so two runs side by side no
# longer report each other's messages.
#
WF_LOG=`mktemp "${TMPDIR:-/tmp}/gitflow-output.XXXXXX"`
if [ $? -gt 0 ] || [ ! -w "$WF_LOG" ]; then
	WF_STATUS=1
	print_err "Could not open a command log in ${TMPDIR:-/tmp}"
	print_build_msg
	exit 1
fi
export WF_LOG

cd "$WF_GIT_ROOT"

WF_REPO=$(git config --get remote.origin.url)
if [ -z "$WF_REPO" ]; then
	WF_STATUS=1
	print_err "Could not read origin URL from the current repository"
	print_build_msg
	exit 1
fi
export WF_REPO

#
# The key check waits for origin, because only origin says which host the stage
# is about to talk to: a project hosted elsewhere is not helped by an answer
# from github.com, and `pr` prints a URL and opens no connection at all. ssh
# closes a successful greeting with 1 - "Hi user! You've successfully
# authenticated" - so 1 is not a failure here; 255 is ssh's own, and anything
# else is not ssh answering, which a missing key is not the explanation for.
#
if needs_github_key; then
	out=$(check_github)
	if [ $? -eq 255 ]; then
		WF_STATUS=1
		print_err "$out"
		echo "Add your private key ssh-add [path to pk]."
		print_build_msg
		exit 1
	fi
fi

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

source "$WF_DIR/commands/${WF_COMMAND}.sh"
if [[ "$WF_COMMAND" == "resolved" && "$WF_ENV" == "sync" ]]; then
	source "$WF_DIR/commands/${WF_COMMAND}-${WF_ENV}.sh"
fi
print_build_msg

# The banner is the report; this is the same answer for a script, an && chain or
# a CI step, which used to read every run as a success whatever it printed.
exit $WF_STATUS
