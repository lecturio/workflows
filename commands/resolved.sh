#!/bin/bash


function setup_branch() {
	emit_failonerror "git checkout $1 print_msg
	emitgit_sync_branch $1 print_msg

	if [ $? -gt 0 ]; then
		print_msg "Resolve conflicts manually"
		exit 1
	fi
}

function setup_master_branch() {
	emit "git checkout master" quiet
	emit_failonerror "git pull --rebase origin master" print_msg
}

# setup feature branch
function setup_feature_branch() {
	local CURRENT_BRANCH=`emit "git rev-parse --abbrev-ref HEAD"`

	if [ "$CURRENT_BRANCH" != "$WF_TASK" ]; then
		emit_failonerror "git checkout $WF_TASK" print_msg
	fi

	emitgit_sync_branch "$WF_TASK" print_msg

	if [ $? -gt 0 ]; then
		print_msg "Resolve conflicts manually"
		exit 1
	fi
}

# setup staging branch
function setup_staging_branch() {
	local EXISTS_LOCALLY=`emitgit_is_local_branch staging print_msg`

	if [ $EXISTS_LOCALLY -eq 0 ]; then
		emit "git checkout staging" quiet
		emitgit_sync_branch staging print_msg

		if [ $? -gt 0 ]; then
			print_msg "Resolve conflicts manually"
			exit 1
		fi
	else
		emit "git checkout -b staging origin/staging"
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

	emit "git cherry-pick -n ${CHERRY_PICK} --strategy recursive -Xtheirs" quiet
	echo git cherry-pick -n ${CHERRY_PICK} --strategy recursive -Xtheirs
	print_msg "Check your changes before commit- possible data loss if merge is incorrect"
}


emit_failonerror_pending_commits "$WF_TASK"

if [ "$WF_ENV" == "" ]; then
	emit "git cherry-pick --abort" quiet
	emit "git fetch" quiet

	setup_branch "master"
	setup_branch "$WF_TASK"
	setup_branch "staging"
	#setup_master_branch
	#setup_feature_branch
	#setup_staging_branch
	sync_feature_changes
fi
