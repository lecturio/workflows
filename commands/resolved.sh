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

	## Duplicated in resolved sync
	local TRACK_NS="$WF_TASK-track-"
	local TRACK_NUM=$(emit "git branch -r | grep $TRACK_NS |\
		sed 's/origin\/$TRACK_NS//' | sort -nr | head -1")

	local TRACK_NUM=$(echo $TRACK_NUM | sed 's/^[ \t]*//')
	local TRACK_BRANCH=${TRACK_NS}${TRACK_NUM}

	if [ "$TRACK_NUM" == "" ]; then
		local CHERRY_PICK=origin/master..$WF_TASK
	else
		local CHERRY_PICK=origin/$TRACK_BRANCH..$WF_TASK
	fi

	emit "git checkout staging" quiet
	#emit "git rev-list --reverse ${CHERRY_PICK} | git cherry-pick -n --stdin"
	emit "git cherry-pick -Xignore-all-space -n ${CHERRY_PICK}" 
	print_msg "Check your changes before commit- possible data loss if merge is incorrect"
	print_msg "Run \"git status\" and check for conflits"
	print_msg "Run \"git cherry-pick --continue\" after conflict resolution"
	print_msg "Run \"gitflow $WF_TASK resolved sync -m\" and put commit message"
}

emit_failonerror_pending_commits "$WF_TASK"

if [ "$WF_ENV" == "" ]; then
	emit "git cherry-pick --abort" quiet
	emit "git fetch" quiet
	emit "git remote prune origin" quiet

	setup_branch "master" && setup_branch "$WF_TASK" && setup_branch "staging"
	sync_feature_changes
	print_msg "gitflow $WF_TASK resolved sync"
fi
