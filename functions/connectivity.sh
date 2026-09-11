#!/bin/bash

function check_github() {
	ssh -T git@github.com 2>&1
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
