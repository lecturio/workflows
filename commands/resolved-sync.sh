#!/bin/bash

print_msg "Sync changes to staging"

# setups tracking branch with recent changes on feature branch
function track_feature_branch() {
	local CURRENT_BRANCH=`emit "git rev-parse --abbrev-ref HEAD"`

	if [ "$CURRENT_BRANCH" != "$WF_TASK" ]; then
		emit_failonerror "git checkout $WF_TASK" print_msg
	fi

	local TRACK_NS="$WF_TASK-track-"
	local TRACK_NUM=$(emit "git branch -r | grep $TRACK_NS |\
		sed 's/origin\/$TRACK_NS//' | sort -nr | head -1")

	local TRACK_NUM=$(echo $TRACK_NUM | sed 's/^[ \t]*//')
	if [ "$TRACK_NUM" == "" ]; then
		local TRACK_NUM=0
	fi

	let "TRACK_NUM=1+${TRACK_NUM}"

	local TRACK_BRANCH=${TRACK_NS}${TRACK_NUM}

	emit_failonerror "git branch --track ${TRACK_BRANCH}" print_msg
	emit_failonerror "git checkout ${TRACK_BRANCH}" quiet
	emit_failonerror "git push origin ${TRACK_BRANCH}" print_msg
}

if [ "$MESSAGE" != "" ]; then
	emit_failonerror "git commit -am \"$MESSAGE\"" print_msg
fi

# init functions
track_feature_branch
setup_branch "staging"

if [ $WF_STATUS -eq 0 ]; then
	print_msg "git push staging"
fi
