#!/bin/bash
# Branch helpers shared by the staging stages

#
# Prepare specific branch for merging.
# $1 - branch name
#
function setup_branch() {
	local BRANCH_EXIST=`emitgit_is_local_branch $1`
	if [ $BRANCH_EXIST -gt 0 ]; then
		emitgit_checkout "-b $1 origin/$1"
	fi

	emitgit_checkout "$1"
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
# Fail when the ticket branch is not in this repository.
#
# The stages that bring it into existence check for themselves - in-progress
# creates it, to-staging and resolved weigh it against origin's copy - but
# deployable and closed used to act on a name nobody had checked: deployable
# leaked git's own "fatal: ambiguous argument 'origin/NOPE-9..NOPE-9'" out of
# its pending-commits check before failing on the checkout behind it, and
# closed matched nothing, deleted nothing and reported BUILD SUCCESS. A stage
# asked to act on a branch that is not there says so and stops.
# $1 - stage name, for the message
#
function require_ticket_branch() {
	emit "git rev-parse --verify --quiet refs/heads/$WF_TASK" quiet
	if [ $? -eq 0 ]; then
		return 0
	fi

	WF_STATUS=1
	print_err "$1 works on the branch $WF_TASK, and it is not in this repository"
	print_msg "Check the name with git branch, or start the ticket: gitflow $WF_TASK in-progress"
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
# A plain "git branch". It used to be "git branch --track", which with no start
# point takes HEAD - the ticket branch - as the thing to track, and wrote
# branch.ABC-123-track-1.remote = . with merge = refs/heads/ABC-123: the
# bookmark followed the local ticket branch, so a "git pull" or "git status" on
# it answered about the ticket's own upstream. A bookmark records where the tip
# was, which is the commit it points at and nothing else.
#
function track_feature_branch() {
	local CURRENT_BRANCH=`emit "git rev-parse --abbrev-ref HEAD"`

	if [ "$CURRENT_BRANCH" != "$WF_TASK" ]; then
		emitgit_checkout "$WF_TASK"
	fi

	local TRACK_BRANCH="$(track_branch_ns)$(next_track_num)"

	emit_failonerror "git branch ${TRACK_BRANCH}" print_msg
	emitgit_checkout "${TRACK_BRANCH}"
	emit_failonerror "git push origin ${TRACK_BRANCH}" print_msg
}
