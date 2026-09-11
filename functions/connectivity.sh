#!/bin/bash

#
# Whether a github.com key is worth checking before the stage runs. The stages
# talk to whatever "origin" is, so on a project hosted anywhere else the answer
# says nothing about the run that follows, and `pr` only prints a compare URL -
# it opens no connection at all. An https origin is not authenticated with an
# ssh key either.
#
function needs_github_key() {
	if [ "$WF_COMMAND" == "pr" ]; then
		return 1
	fi

	case "$WF_REPO" in
		git@github.com:* | ssh://git@github.com/*)
			return 0
			;;
	esac

	return 1
}

#
# BatchMode, so a host key nobody has seen before is refused rather than asked
# about: this runs before the stage, where a prompt has nothing to do with what
# was typed and nothing in a script or a CI step to answer it.
#
function check_github() {
	ssh -o BatchMode=yes -T git@github.com 2>&1
}

function check_update() {
	emit "git fetch" quiet
	SELF_UPDATE=`emit "git rev-list --left-right --boundary @{u}..."`
	
	if [ "$SELF_UPDATE" ]; then
		WF_STATUS=1
		print_err "Update workflows to the latest version"
		print_msg "gitflow self update"
		print_build_msg
		exit 1
	fi
}
