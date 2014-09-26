#!/bin/bash

function check_github() {
	ssh -T git@github.com 2>&1
}

function check_update() {
	emit "git fetch" quiet
	SELF_UPDATE=`emit "git rev-list --left-right --boundary @{u}..."`
	
	if [ "$SELF_UPDATE" ]; then
		print_err "Update local branch with remote"
		print_msg "git pull --rebase origin master"
		exit 1
	fi
}
