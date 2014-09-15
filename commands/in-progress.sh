#!/bin/bash

echo "in progress command"
emit "git fetch" quiet

emit "git show-ref --verify refs/heads/$WF_TASK" quiet
EXISTS_LOCALLY=$?
EXISTS_REMOTELY=`emit "git branch -r | grep origin/${WF_TASK}$"`

if [ $EXISTS_LOCALLY -eq 0 ]; then
	emit "git checkout $WF_TASK"
else
	if [ $EXISTS_REMOTELY ]; then
		emit "git checkout -b $WF_TASK origin/$WF_TASK"
	else
		emit "git checkout -b $WF_TASK origin/master"
		emit "git push origin $WF_TASK"
	fi
	
fi
