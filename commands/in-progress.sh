#!/bin/bash

refresh_origin
require_origin_branch "$WF_PROD_BRANCH"
emit "git show-ref --verify refs/heads/$WF_TASK" quiet
EXISTS_LOCALLY=$?
EXISTS_REMOTELY=`emit "git branch -r --list origin/${WF_TASK}"`

if [ $EXISTS_LOCALLY -eq 0 ]; then
	emitgit_checkout "$WF_TASK"
else
	if [ $EXISTS_REMOTELY ]; then
		emitgit_checkout "-b $WF_TASK origin/$WF_TASK"
	else
		emitgit_checkout "-b $WF_TASK origin/$WF_PROD_BRANCH"
		emit "git push origin $WF_TASK" print_msg
		emit "git branch -u origin/$WF_TASK" print_msg
	fi

fi

emitgit_sync_branch $WF_TASK print_msg
