#!/bin/bash

_completion() {
	local cur prev opts _ret=1
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"
	let cword=COMP_CWORD-1
	let _ret && _ret=0
	opts="in-progress resolved deployable closed"

	#echo $cur :: $prev :: $cword :: $ret >> aa.log

	if [[ ${cur} == "%%:*" ]]; then
		COMPREPLY=( $(compgen -W "${opts}" ${cur}) )
	elif [[ $cword -eq 1 ]]; then
		COMPREPLY=( $(compgen -W "${opts}" ${cur}) )
	elif [[ $prev == "resolved" ]]; then
		COMPREPLY=( $(compgen -W "sync" ${cur}) )
	elif [[ $prev == "sync" && $cword == 3 ]]; then
		COMPREPLY=( $(compgen -W "-m" ${cur}) )
	fi

	return 0
}

complete -F _completion -o filenames gitflow /usr/local/bin/gitflow