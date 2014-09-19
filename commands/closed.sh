#!/bin/bash

emit "git checkout master" quiet

# List local or remote branches for task
# $1 - -r for remote branches
__git_delete_remote_branch() {
	local BRANCH=""
	for x in `git branch $1 | grep $WF_TASK`; 
	do 
		local BRANCH="$BRANCH `echo $x | sed 's/\// :/' | sed 's/origin//'`"
	done

	echo $BRANCH
}

REMOTE_BRANCEHS=`__git_delete_remote_branch -r`;
LOCAL_BRANCEHS=`__git_delete_remote_branch`;

NOTICE=`echo $REMOTE_BRANCEHS | tr " " "\n"`
NOTICE="$NOTICE 
`echo $LOCAL_BRANCEHS | tr " " "\n"`"

read -p "Delete branches for $WF_TASK [y] or [n]? 
$NOTICE
: " answer

while true
do
  case $answer in
   [yY]* ) echo git push origin $REMOTE_BRANCEHS
	   echo git branch -d $LOCAL_BRANCEHS
           break;;

   [nN]* )  exit 0;;

   * )     exit 0;;
  esac
done
