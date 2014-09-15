#!/bin/bash

emit "git fetch" quiet
emit "git show-ref --verify refs/heads/$WF_TASK" quiet
EXISTS_LOCALLY=$?
EXISTS_REMOTELY=`emit "git branch -r | grep origin/${WF_TASK}$"`

if [ $EXISTS_LOCALLY -eq 0 ]; then
	emit "git checkout $WF_TASK"
else
	if [ $EXISTS_REMOTELY ]; then
		emit "git checkout -b $WF_TASK origin/$WF_TASK" print_msg
	else
		emit "git checkout -b $WF_TASK origin/master" print_msg
		emit "git push origin $WF_TASK" print_msg
	fi
	
fi
