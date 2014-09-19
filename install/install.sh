#!/bin/bash

WF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

EXEC_DIR=`dirname $WF_DIR`
sudo rm -rf /usr/local/bin/gitflow
sudo ln -s $EXEC_DIR/workflow.sh /usr/local/bin/gitflow
