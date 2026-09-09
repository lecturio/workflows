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
	emit "git cherry-pick --abort" quiet
	refresh_origin

	require_origin_branch "$WF_PROD_BRANCH"
	require_origin_branch "$WF_STAGING_BRANCH"
	setup_branch "$WF_PROD_BRANCH" && setup_branch "$WF_TASK" && setup_branch "$WF_STAGING_BRANCH"
	sync_feature_changes
	print_msg "gitflow $WF_TASK resolved sync"
fi
