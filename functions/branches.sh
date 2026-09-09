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
		WF_STATUS=1
		print_err "Could not bring $1 up to date with origin/$1"
		print_msg "Resolve conflicts manually"
		print_build_msg
		exit 1
	fi
}

#
# Refuse unless the staging branch is the one checked out. Both staging stages
# commit where HEAD stands and then bookmark the ticket as synced, so a commit
# that lands on any other branch is recorded as synced with staging holding none
# of it. The whole ref is compared: a detached HEAD reports itself as "HEAD".
# $1 - stage name, for the message
#
function require_staging_checked_out() {
	local HEAD_REF=`git symbolic-ref --quiet HEAD 2>/dev/null`

	if [ "$HEAD_REF" == "refs/heads/$WF_STAGING_BRANCH" ]; then
		return 0
	fi

	WF_STATUS=1
	if [ "$HEAD_REF" == "" ]; then
		print_err "$1 commits onto $WF_STAGING_BRANCH, and HEAD is detached"
	else
		print_err "$1 commits onto $WF_STAGING_BRANCH, and ${HEAD_REF#refs/heads/} is checked out"
	fi
	print_build_msg
	exit 1
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
# Read through for-each-ref rather than "git branch", which decorates its output
# - colour when color.branch is forced to always, "*" or "+" in front of a
# checked-out branch - and a decorated line matches none of this.
#
function highest_track_num() {
	local TRACK_NS="$(track_branch_ns)"

	git for-each-ref --format='%(refname:short)' "refs/remotes/origin/${TRACK_NS}*" |\
		sed -n "s|^origin/${TRACK_NS}\([0-9][0-9]*\)$|\1|p" |\
		sort -nr | head -1
}

#
# The number for the next bookmark. Counted over the local branches as well as
# origin's, because the two can disagree: when the push of a bookmark fails the
# local branch is left behind, and numbering from origin alone would pick that
# same number again and stop at "a branch named ABC-123-track-1 already
# exists" on every later run. Only origin decides the sync point, which is why
# highest_track_num stays origin-only - a local-only bookmark is not a ref
# origin/... can be built from.
#
function next_track_num() {
	local TRACK_NS="$(track_branch_ns)"
	local HIGHEST=$(git for-each-ref --format='%(refname:short)' \
			"refs/heads/${TRACK_NS}*" "refs/remotes/origin/${TRACK_NS}*" |\
		sed -n -e "s|^${TRACK_NS}\([0-9][0-9]*\)$|\1|p" \
			-e "s|^origin/${TRACK_NS}\([0-9][0-9]*\)$|\1|p" |\
		sort -nr | head -1)

	if [ "$HIGHEST" == "" ]; then
		HIGHEST=0
	fi

	echo $((10#$HIGHEST + 1))
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

	local TRACK_BRANCH="$(track_branch_ns)$(next_track_num)"

	emit_failonerror "git branch --track ${TRACK_BRANCH}" print_msg
	emit_failonerror "git checkout ${TRACK_BRANCH}" quiet
	emit_failonerror "git push origin ${TRACK_BRANCH}" print_msg
}
