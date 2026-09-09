#!/bin/bash

#
# Executes a command.
# $1 - the command
# $2 - "quiet" to throw its output away, "print_msg" to report it through [INFO];
#      without it the command writes straight to the terminal
#
function emit() {
	if [ "$2" == "quiet" ]; then
		eval $1 >/dev/null 2>&1
	elif [ "$2" == "print_msg" ]; then
		$(eval $1 >$WF_DIR/output.log 2>&1)
		WF_STATUS=$?
		print_msg "`tail $WF_DIR/output.log`"
	else
		eval $1
	fi
}

#
# The same, but a failing command ends the run. In "print_msg" mode it is quiet
# while the command succeeds and reports through [ERROR] when it does not.
#
function emit_failonerror() {
	if [ "$2" == "quiet" ]; then
		eval $1 >/dev/null 2>&1
		if [ $? -gt 0 ]; then
			exit 1
		fi
	elif [ "$2" == "print_msg" ]; then
		$(eval $1 >$WF_DIR/output.log 2>&1)
		WF_STATUS=$?
		if [ $WF_STATUS -gt 0 ]; then
			print_err "`tail $WF_DIR/output.log`"
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
}

function emitgit_abort_rebase() {
	emit "git rebase --abort"
}

function emitgit_sync_branch() {
	emit "git pull --rebase origin $1" "$2"
}

#
# Check a branch out, or end the run reporting why.
#
# Every stage acts on the branch it has just checked out - deletes it, rebases
# it, commits onto it - so a checkout whose failure is discarded leaves the
# commands after it running against whatever HEAD happens to be. That is how
# `closed` deleted the ticket from origin while keeping it locally, and how
# `deployable` rebased the ticket onto itself twice and reported BUILD SUCCESS
# with production untouched.
#
# git's own reason is printed, because the causes need different answers: a
# worktree holding changes the switch would overwrite, a branch another
# worktree has checked out, a name two remotes carry. Silent while it works.
#
# What git said is left in output.log either way, so a stage for which the
# switch is the point rather than plumbing can report it - see in-progress.
#
# $1 - the branch, or the arguments of a checkout that creates one
#      ("-b ABC-123 origin/master")
#
function emitgit_checkout() {
	emit_failonerror "git checkout $1" print_msg
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
		WF_STATUS=1
		print_err "Local changes need to be pushed to ${1}"
		print_build_msg
		exit 1
	fi
}
