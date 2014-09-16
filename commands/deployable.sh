#!/bin/bash

echo "deployable"

emit "git rebase --abort" quiet

emit "git checkout master" quiet
emit_failonerror "git pull --rebase origin master" print_msg

emit "git checkout $WF_TASK" quiet
emit_failonerror "git pull --rebase origin $WF_TASK"
emit_failonerror "git rebase master" print_msg

emit "git checkout master" quiet
emit_failonerror "git rebase $WF_TASK"
print_msg "Push your changes to master"
