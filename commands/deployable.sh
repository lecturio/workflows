#!/bin/bash

emit "git rebase --abort" quiet

#
# sync branch
#
__setup_branch() {
	emit "git checkout $1" quiet
	emit_failonerror "git pull --rebase origin $1" print_msg
}

#
# $1 - branch that needs merge
# $2 - rebase to given branch
#
__merge_branch() {
	emit "git checkout $1" quiet
	emit_failonerror "git rebase $2"
}

emit "git remote prune origin" quiet

__setup_branch "master"

PENDING_COMMITS=`emit "git log origin/${WF_TASK}..${WF_TASK}"`
if [ "$PENDING_COMMITS" == "" ]; then 
	#TODO either push branch to remote
	__setup_branch "$WF_TASK"
fi

__merge_branch "$WF_TASK" master && __merge_branch master "$WF_TASK"
