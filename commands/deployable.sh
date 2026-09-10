#!/bin/bash

#
# This used to be "git rebase --abort", quiet and unconditional, run before
# anything had been looked at: a rebase you were half way through - this
# stage's own, or one you started yourself for a reason of your own - was
# rewound with nothing printed to say so, and whatever had been resolved in it
# went with it. The stage refuses instead. It rebases the ticket onto production
# and then production onto the ticket, and neither of those can carry a paused
# operation forward, so every one of them is handed back to git.
#
require_nothing_in_flight deployable
refuse_finished_pick_state deployable

#
# sync branch
#
__setup_branch() {
	emitgit_checkout "$1"
	emit_failonerror "git pull --rebase origin $1" print_msg
}

#
# $1 - branch that needs merge
# $2 - rebase to given branch
#
__merge_branch() {
	emitgit_checkout "$1"
	emit_failonerror "git rebase -Xignore-all-space $2"
}

refresh_origin
require_origin_branch "$WF_PROD_BRANCH"
__setup_branch "$WF_PROD_BRANCH"

PENDING_COMMITS=`emit "git log origin/${WF_TASK}..${WF_TASK}"`
if [ "$PENDING_COMMITS" == "" ]; then 
	#TODO either push branch to remote
	__setup_branch "$WF_TASK"
fi

__merge_branch "$WF_TASK" "$WF_PROD_BRANCH" && __merge_branch "$WF_PROD_BRANCH" "$WF_TASK"
