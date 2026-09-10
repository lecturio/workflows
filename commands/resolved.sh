#!/bin/bash

# cherry pick changes
function sync_feature_changes() {
	local CHERRY_PICK="$(cherry_pick_range)"

	emitgit_checkout "$WF_STAGING_BRANCH"
	#emit "git rev-list --reverse ${CHERRY_PICK} | git cherry-pick -n --stdin"
	emit "git cherry-pick -Xignore-all-space -n ${CHERRY_PICK}" 
	print_msg "Check your changes before commit- possible data loss if merge is incorrect"
	print_msg "Run \"git status\" and check for conflits"
	print_msg "Run \"git cherry-pick --continue\" after conflict resolution"
	print_msg "Run \"gitflow $WF_TASK resolved sync -m\" and put commit message"
}

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
	print_msg "gitflow $WF_TASK resolved sync"
fi
