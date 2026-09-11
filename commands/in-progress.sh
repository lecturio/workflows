#!/bin/bash

refresh_origin
require_origin_branch "$WF_PROD_BRANCH"
emit "git show-ref --verify refs/heads/$WF_TASK" quiet
EXISTS_LOCALLY=$?
EXISTS_REMOTELY=`emit "git branch -r --list origin/${WF_TASK}"`

#
# Where the switch left you, which is this stage's whole point - the shared
# checkout is quiet while it works, because everywhere else it is plumbing.
# Only git's first line: what follows it is the branch's standing against
# origin, which the pull at the end of the stage reports for itself. Read from
# the run's log before anything else writes over it.
#
__report_checkout() {
	print_msg "`head -1 "$WF_LOG"`"
}

if [ $EXISTS_LOCALLY -eq 0 ]; then
	emitgit_checkout "$WF_TASK"
	__report_checkout
else
	# The listing as a string, not as the arguments of the test: unquoted it was
	# word-split, and "gitflow HEAD in-progress" - where git answers
	# "origin/HEAD -> origin/master" - printed
	# "[: ->: binary operator expected" before the stage carried on
	if [ -n "$EXISTS_REMOTELY" ]; then
		emitgit_checkout "-b $WF_TASK origin/$WF_TASK"
		__report_checkout
	else
		emitgit_checkout "-b $WF_TASK origin/$WF_PROD_BRANCH"
		__report_checkout
		emit "git push origin $WF_TASK" print_msg
		emit "git branch -u origin/$WF_TASK" print_msg
	fi

fi

emitgit_sync_branch $WF_TASK print_msg
