#!/bin/bash

WF_ARGC=$#
SYNC_OPTION="$4"

#
# "sync" is the only word this stage takes in the option slot, and -m belongs to
# that half: the cherry-pick commits nothing, so it has no message to carry.
# Anything else used to fall through both the "$WF_ENV" == "" body below and the
# "sync" test in workflow.sh, so "resolved snyc" and "resolved -m msg" did
# nothing at all and ended BUILD SUCCESS, which reads as a sync that happened.
# to-staging spells the same grammar out for itself in require_no_option; the
# words the two stages take differ, so they are not one function.
#
function require_known_option() {
	local ALLOWED=0 REASON=""
	local STAGE="resolved" OFFENDER="$WF_ENV"
	local USAGE="gitflow $WF_TASK resolved [sync [-m \"message\"]]"

	case "$WF_ENV" in
		"")
			OFFENDER="$SYNC_OPTION"
			[ "$WF_ARGC" -le 2 ] && ALLOWED=1
			;;
		sync)
			STAGE="resolved sync"
			OFFENDER="$SYNC_OPTION"
			USAGE="gitflow $WF_TASK resolved sync [-m \"message\"]"
			case "$SYNC_OPTION" in
				"")
					[ "$WF_ARGC" -le 3 ] && ALLOWED=1
					;;
				-m | --message)
					# the message follows, and every word after it belongs to it
					ALLOWED=1
					;;
				-m* | --message=*)
					# an attached form carries its message inside that one word,
					# so nothing may come after it. An empty value (-m,
					# --message=) is allowed through so the check below can say
					# a message is missing rather than call it an option
					if [ "$WF_ARGC" -le 4 ]; then
						ALLOWED=1
					else
						REASON="$SYNC_OPTION carries the whole message, so nothing may follow it"
					fi
					;;
			esac
			;;
	esac

	if [ $ALLOWED -eq 0 ]; then
		WF_STATUS=1
		if [ -z "$REASON" ]; then
			REASON="$STAGE does not take \"$OFFENDER\""
		fi
		print_err "$REASON: $USAGE"
		print_build_msg
		exit 1
	fi

	MESSAGE="`trim_whitespace "$MESSAGE"`"

	# -m with nothing after it, or nothing but spaces. Falling back to no
	# message at all would bookmark the round without committing what is
	# staged, which is the opposite of what someone who typed -m asked for, and
	# git would not keep such a message either: it strips a blank subject line.
	if [[ -n "$SYNC_OPTION" && -z "$MESSAGE" ]]; then
		WF_STATUS=1
		print_err "$SYNC_OPTION needs a message: gitflow $WF_TASK resolved sync -m \"message\""
		print_msg "Leave it out to bookmark a round you committed yourself"
		print_build_msg
		exit 1
	fi
}

#
# cherry pick changes
#
# The pick is the whole of this stage, so how it ended is how the run ended. It
# is meant to stop on a conflict - -n leaves the resolution staged and the tree
# is yours to look at - but stopping is not succeeding: nothing has reached
# staging, the round still needs finishing, and the run used to say
# BUILD SUCCESS over a tree full of conflict markers. It reports the conflict
# the way to-staging reports its own, with the same recovery lines, since it is
# the same state.
#
function sync_feature_changes() {
	local CHERRY_PICK="$(cherry_pick_range)"
	local PICK_STATUS

	emitgit_checkout "$WF_STAGING_BRANCH"

	# An empty range is not a failure, and git makes one: "error: empty commit
	# set passed", which as a pick error would send you to a "git cherry-pick
	# --abort" with no cherry-pick to abort.
	if [ -z "`git log --format=%h -1 "$CHERRY_PICK"`" ]; then
		print_msg "$WF_STAGING_BRANCH is already level with $WF_TASK - nothing to cherry-pick"
		print_build_msg
		exit 0
	fi

	emit "git cherry-pick -Xignore-all-space -n ${CHERRY_PICK}"
	PICK_STATUS=$?

	if [ -n "`git ls-files -u`" ]; then
		fail_on_conflict
	elif [ $PICK_STATUS -gt 0 ]; then
		fail_on_pick_error "$CHERRY_PICK"
	fi

	print_msg "Review what is staged: git status, git diff --cached"
	print_msg "Then commit and bookmark it: gitflow $WF_TASK resolved sync -m \"message\""
	print_msg "Or commit it yourself first, and bookmark with: gitflow $WF_TASK resolved sync"
}

require_known_option
emit_failonerror_pending_commits "$WF_TASK"

if [ "$WF_ENV" == "" ]; then
	#
	# This used to be "git cherry-pick --abort", quiet and unconditional, run
	# before anything had been looked at: a conflict resolved by hand and
	# "git add"-ed was reverted to what staging held before the pick, with
	# nothing printed to say so, and a cherry-pick of your own on any branch
	# went the same way. The stage refuses instead. A cherry-pick of this
	# ticket's own range is the one thing it can name a next step for -
	# finishing a hand-resolved sync is what "resolved sync" is for - and
	# everything else goes back to git and to whoever started it.
	#
	require_nothing_in_flight resolved own-pick
	refuse_finished_pick_state resolved

	refresh_origin

	require_origin_branch "$WF_PROD_BRANCH"
	require_origin_branch "$WF_STAGING_BRANCH"
	setup_branch "$WF_PROD_BRANCH" && setup_branch "$WF_TASK" && setup_branch "$WF_STAGING_BRANCH"
	sync_feature_changes
fi
