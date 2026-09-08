#!/bin/bash
# Branch helpers shared by the staging stages

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

#
# Name prefix of the ticket's tracking branches: ABC-123-track-
#
function track_branch_ns() {
	printf '%s' "$WF_TASK-track-"
}

#
# Highest N among the origin/ABC-123-track-N bookmarks, empty when the ticket
# has none yet. Only exact origin/<ticket>-track-<digits> names count: matching
# the namespace loosely picked up another ticket whose name ends with this one
# (origin/XABC-track-9 while syncing ABC) and bookmarks on other remotes
# (upstream/ABC-track-77), and either one becomes a range git cannot resolve.
# Plain git, not emit(): emit() is for the commands that change something.
#
function highest_track_num() {
	local TRACK_NS="$(track_branch_ns)"

	git branch -r --list "origin/${TRACK_NS}*" |\
		sed -n "s|^[[:space:]]*origin/${TRACK_NS}\([0-9][0-9]*\)$|\1|p" |\
		sort -nr | head -1
}

#
# The ticket commits staging has not seen yet: everything since the newest
# bookmark, or the whole ticket branch when there is no bookmark.
#
function cherry_pick_range() {
	local TRACK_NUM="$(highest_track_num)"

	if [ "$TRACK_NUM" == "" ]; then
		printf '%s' "origin/$WF_PROD_BRANCH..$WF_TASK"
	else
		printf '%s' "origin/$(track_branch_ns)${TRACK_NUM}..$WF_TASK"
	fi
}

#
# Bookmark the ticket-branch tip that was just put on staging, and push it.
# Leaves you on the new tracking branch.
#
function track_feature_branch() {
	local CURRENT_BRANCH=`emit "git rev-parse --abbrev-ref HEAD"`

	if [ "$CURRENT_BRANCH" != "$WF_TASK" ]; then
		emit_failonerror "git checkout $WF_TASK" print_msg
	fi

	local TRACK_NUM="$(highest_track_num)"
	if [ "$TRACK_NUM" == "" ]; then
		local TRACK_NUM=0
	fi

	let "TRACK_NUM=1+${TRACK_NUM}"

	local TRACK_BRANCH="$(track_branch_ns)${TRACK_NUM}"

	emit_failonerror "git branch --track ${TRACK_BRANCH}" print_msg
	emit_failonerror "git checkout ${TRACK_BRANCH}" quiet
	emit_failonerror "git push origin ${TRACK_BRANCH}" print_msg
}
