#!/bin/bash

refresh_origin
require_origin_branch "$WF_PROD_BRANCH"
emit "git checkout $WF_PROD_BRANCH" quiet

# List local or remote branches for task
# $1 - -r for remote branches
__git_delete_remote_branch() {
	local BRANCH=""
	for x in `git branch $1 | grep -w $WF_TASK`;
	do
		local BRANCH="$BRANCH `echo $x | sed 's/\// :/' | sed 's/origin//'`"
	done

	echo $BRANCH
}

REMOTE_BRANCEHS=`__git_delete_remote_branch -r`;
LOCAL_BRANCEHS=`__git_delete_remote_branch`;

if [[ -n "$REMOTE_BRANCEHS" ]]; then
	emit "git push origin $REMOTE_BRANCEHS"
fi
if [[ -n "$LOCAL_BRANCEHS" ]]; then
	emit "git branch -D $LOCAL_BRANCEHS"
fi
