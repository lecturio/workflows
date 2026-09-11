#!/bin/bash

WF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

EXEC_DIR=`dirname "$WF_DIR"`

sudo mkdir -p /usr/local/bin

#
# What is already at that path has to go before the link can take it, and the
# removal is read. `rm -f` refuses a directory - which is the case `rm -rf` used
# to swallow, and the reason it is not `rm -rf` any more - and `ln -s` then
# succeeds by putting the link inside it, as /usr/local/bin/gitflow/workflow.sh:
# nothing on PATH, an installer that printed nothing, and `gitflow` answering
# `permission denied` from a directory. The same goes for a path this user
# cannot replace at all.
#
sudo rm -f /usr/local/bin/gitflow
if [ $? -gt 0 ]; then
	echo "Could not replace /usr/local/bin/gitflow - remove it by hand, then run this again" >&2
	exit 1
fi

sudo ln -s "$EXEC_DIR/workflow.sh" /usr/local/bin/gitflow
