#!/bin/bash

#TODO move to external file
function track_feature_branch() {
	local CURRENT_BRANCH=`emit "git rev-parse --abbrev-ref HEAD"`

	if [ "$CURRENT_BRANCH" != "$WF_TASK" ]; then
		emit_failonerror "git checkout $WF_TASK" print_msg
	fi

	local TRACK_BRANCH=`emit "git branch | grep ${WF_TASK}-track-* | sort -r | head -1"`
	if [ "${TRACK_BRANCH##*-}" == "" ]; then
		local TRACK_NUM=1
	else
		let "TRACK_NUM=1+${TRACK_BRANCH##*-}"
	fi

	local TRACK_BRANCH=${WF_TASK}-track-${TRACK_NUM}

	emit_failonerror "git branch --track ${TRACK_BRANCH}" print_msg
	emit_failonerror "git checkout ${TRACK_BRANCH}" quiet
	emit_failonerror "git push origin ${TRACK_BRANCH}" print_msg
}

#TODO move to external file
if [ "$WF_ENV" == "commit" ]; then
	if [ "$MESSAGE" == "" ]; then

		print_err "Commit message is required"
		WF_STATUS=1
		print_build_msg
		exit 1
	fi

	emit_failonerror "git commit -am \"$MESSAGE\"" print_msg
	# create track branch
	track_feature_branch

	emit "git checkout staging"
	print_build_msg
	exit 0
fi

if [ "$WF_ENV" == "sync" ]; then
	emit "git cherry-pick --continue"
	exit 0
fi

emit "git cherry-pick --abort" quiet
emit "git fetch" quiet

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

setup_feature_branch
setup_staging_branch

function sync_feature_changes() {
	local TRACK_BRANCH=`emit "git branch -r | grep ${WF_TASK}-track-* | sort -r | head -1"`

	if [ "$TRACK_BRANCH" == "" ]; then
		local CHERRY_PICK=master..$WF_TASK
	else
		local CHERRY_PICK=$TRACK_BRANCH..$WF_TASK
	fi

	if [ "$WF_ENV" == "force" ]; then
		emit "git cherry-pick -n ${CHERRY_PICK} --strategy recursive -Xtheirs" quiet
		echo git cherry-pick -n ${CHERRY_PICK} --strategy recursive -Xtheirs
		print_msg "Check your changes before commit- possible data loss if merge is incorrect"
	else
		emit "git cherry-pick -n $CHERRY_PICK" print_msg
		if [ $WF_STATUS -gt 0 ]; then
			print_msg "Try with force option"
		fi
	fi
}

#TODO move to external file
# commit and push to one operation
if [ "$WF_ENV" == "push" ]; then
	setup_staging_branch
	if [ $WF_STATUS -eq 0 ]; then
		echo "git push staging"
	fi

	print_build_msg
	exit 0
fi

sync_feature_changes
