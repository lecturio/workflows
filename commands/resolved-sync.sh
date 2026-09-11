#!/bin/bash

print_msg "Sync changes to $WF_STAGING_BRANCH"

require_staging_checked_out "resolved sync"

#
# The message goes to git in a file, the way to-staging writes its own: emit
# re-parses the command string it is given, and the message is text you typed
# rather than something we wrote, so -m 'oops $(id)' ran id.
#
if [ "$MESSAGE" != "" ]; then
	MSG_FILE=`mktemp "${TMPDIR:-/tmp}/gitflow-msg.XXXXXX"`
	trap 'rm -f "$MSG_FILE"' EXIT
	printf '%s\n' "$MESSAGE" > "$MSG_FILE"
	emit_failonerror "git commit -a -F \"$MSG_FILE\"" print_msg
fi

refresh_origin
require_origin_branch "$WF_STAGING_BRANCH"

# init functions
track_feature_branch
setup_branch "$WF_STAGING_BRANCH"

# "git push staging" is not a command anybody can run - it reads as pushing to a
# remote called staging - and the push this stage leaves you is the one
# to-staging names: git push origin staging.
if [ $WF_STATUS -eq 0 ]; then
	print_msg "Now push it: git push origin $WF_STAGING_BRANCH"
fi
