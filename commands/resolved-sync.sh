#!/bin/bash

print_msg "Sync changes to $WF_STAGING_BRANCH"

if [ "$MESSAGE" != "" ]; then
	emit_failonerror "git commit -am \"$MESSAGE\"" print_msg
fi

refresh_origin
require_origin_branch "$WF_STAGING_BRANCH"

# init functions
track_feature_branch
setup_branch "$WF_STAGING_BRANCH"

if [ $WF_STATUS -eq 0 ]; then
	print_msg "git push $WF_STAGING_BRANCH"
fi
