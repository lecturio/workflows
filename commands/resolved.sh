#!/bin/bash

#
# Prepare specific branch for merging.
# $1 - branch name
#
function setup_branch() {
	local BRANCH_EXIST=`emitgit_is_local_branch $1`
	if [ $BRANCH_EXIST -gt 0 ]; then
		emit_failonerror "git checkout -b $1 origin/$1"
	fi

	emit_failonerror "git checkout $1"
	emitgit_sync_branch $1

	if [ $? -gt 0 ]; then
		print_msg "Resolve conflicts manually"
		exit 1
	fi
}

# cherry pick changes
function sync_feature_changes() {
	local TRACK_BRANCH=`emit "git branch -r | grep ${WF_TASK}-track-* | sort -r | head -1"`

	if [ "$TRACK_BRANCH" == "" ]; then
		local CHERRY_PICK=origin/master..$WF_TASK
	else
		local CHERRY_PICK=$TRACK_BRANCH..$WF_TASK
	fi

	emit "git checkout staging" quiet
	emit "git rev-list --reverse ${CHERRY_PICK} | git cherry-pick -n --stdin --strategy recursive -Xours"
	print_msg "Check your changes before commit- possible data loss if merge is incorrect"
}

emit_failonerror_pending_commits "$WF_TASK"

if [ "$WF_ENV" == "" ]; then
	emit "git cherry-pick --abort" quiet
	emit "git fetch" quiet

	setup_branch "master" && setup_branch "$WF_TASK" && setup_branch "staging"
	sync_feature_changes
	print_msg "gitflow $WF_TASK resolved sync"
fi
