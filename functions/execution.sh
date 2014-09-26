#!/bin/bash

#
# executes specific command
# $1 - bash command to execute
# $2 - debug $1 (just print it)
# $2 - append print_msg on output 
#
function emit() {
	echo "emit $1"
	if [[ $WF_DEBUG -eq 1 || "$2" == "debug" ]]; then
		echo -n "info>>> "
		echo "$1 <<<"
	else
		if [ "$2" == "quiet" ]; then
			local hidden=`eval $1 >/dev/null 2>&1`
		elif [ "$2" == "print_msg" ]; then
			local out=`eval $1 >/dev/null 2>&1`
			WF_STATUS=$?
			print_msg "$out"
		else
			eval $1
		fi
	fi
}

function emit_failonerror() {
	echo "  fail $1"
	if [[ $WF_DEBUG -eq 1 || "$2" == "debug" ]]; then
		echo -n "info>>> "
		echo "$1 <<<"
	else
		if [ "$2" == "quiet" ]; then
			local hidden=`eval $1 >/dev/null 2>&1`
			if [ $? -gt 0 ]; then
				exit 1
			fi
		elif [ "$2" == "print_msg" ]; then
			local out=`eval $1 >/dev/null 2>&1`
			if [ $? -gt 0 ]; then
				print_err "$out"
				print_msg - line
				print_msg "BUILD FAILURE"
				print_msg - line
				exit 1
			fi
			
		else
			eval $1
			if [ $? -gt 0 ]; then
				exit 1
			fi

		fi
	fi
}

function emitgit_abort_rebase() {
	emit "git rebase --abort"
}

function emitgit_sync_branch() {
	emit "git pull --rebase origin $1" "$2"
}

#
# Checks if branch is in local repository.
# $1 - branch to be checked
#
function emitgit_is_local_branch() {
	emit "git show-ref --verify refs/heads/$1" quiet
	echo $?
}

#
# Checks if there pending commits in certain branches
# $1 - branch to be checked
#
emit_failonerror_pending_commits() {
	PENDING_COMMITS=`emit "git log origin/${1}..${1}"`
	if [ "$PENDING_COMMITS" != "" ]; then
		print_err "Local changes need to be pushed to ${1}"
		print_build_msg
		exit 1
	fi
}
