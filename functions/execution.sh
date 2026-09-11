#!/bin/bash

#
# Executes a command.
# $1 - the command
# $2 - "quiet" to throw its output away, "print_msg" to report it through [INFO];
#      without it the command writes straight to the terminal
#
# A command that fails raises WF_STATUS, and nothing lowers it again: the status
# is the outcome of the run and not of its last command. It used to be assigned
# outright, so in-progress reporting a push it could not make went on to a pull
# that worked and ended the run with BUILD SUCCESS.
#
function emit() {
	if [ "$2" == "quiet" ]; then
		eval $1 >/dev/null 2>&1
	elif [ "$2" == "print_msg" ]; then
		$(eval $1 >$WF_DIR/output.log 2>&1)
		if [ $? -gt 0 ]; then
			WF_STATUS=1
		fi
		print_msg "`tail $WF_DIR/output.log`"
	else
		eval $1
	fi
}

#
# The same, but a failing command ends the run, reporting BUILD FAILURE like
# every other way out. In "print_msg" mode it is quiet while the command
# succeeds and reports through [ERROR] when it does not.
#
# The status is kept apart from WF_STATUS: a failure raised earlier in the run
# would otherwise read here as this command having failed.
#
function emit_failonerror() {
	local STATUS
	if [ "$2" == "quiet" ]; then
		eval $1 >/dev/null 2>&1
		STATUS=$?
	elif [ "$2" == "print_msg" ]; then
		$(eval $1 >$WF_DIR/output.log 2>&1)
		STATUS=$?
		if [ $STATUS -gt 0 ]; then
			print_err "`tail $WF_DIR/output.log`"
		fi
	else
		eval $1
		STATUS=$?
	fi

	if [ $STATUS -gt 0 ]; then
		WF_STATUS=1
		print_build_msg
		exit 1
	fi
}

#
# Run git with its arguments kept apart, and end the run if it fails.
#
# Nothing is eval'd here, which is the point: emit re-parses the command string
# it is given, and a branch name is data the repository hands us, not something
# we wrote. Git allows ; $( ) ` & | in a ref name - only spaces, globs and a
# few others are forbidden - so a branch pushed as "ABC-123;id" ran id on the
# machine of whoever closed the ticket.
#
# $@ - the git subcommand and its arguments, one to a word
#
function gitrun_failonerror() {
	git "$@"
	if [ $? -gt 0 ]; then
		WF_STATUS=1
		print_build_msg
		exit 1
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
