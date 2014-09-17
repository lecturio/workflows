#!/bin/bash

print_msg "Sync changes to staging"

emit_failonerror_pending_commits "$WF_TASK"

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

if [ "$MESSAGE" != "" ]; then
	emit_failonerror "git commit -am \"$MESSAGE\"" print_msg
fi

# create track branch
track_feature_branch
setup_staging_branch
if [ $WF_STATUS -eq 0 ]; then
	print_msg "git push staging"
fi
