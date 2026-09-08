#!/bin/bash

_completion() {
	local cur prev opts _ret=1
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"
	let cword=COMP_CWORD-1
	let _ret && _ret=0
	opts="in-progress to-staging resolved deployable closed pr"
	self_opts="update"

	if [[ $WF_DEBUG -eq 1 ]]; then
		echo $cur :: $prev :: $cword :: $ret >> aa.log
	fi

	if [[ ${cword} -eq 0 ]]; then
		if [[ $cur == *origin* ]]; then
			COMPREPLY=( $(compgen -W "$(git branch -r 2>/dev/null)" -- "${cur}") )
		else
			COMPREPLY=( $(compgen -W "$(git branch 2>/dev/null) origin/ self" -- "${cur}") )
		fi
		elif [[ $cword -eq 1 ]]; then
			if [[ $prev == "self" ]]; then
				COMPREPLY=( $(compgen -W "${self_opts}" -- "${cur}") )
			else
				COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
			fi
		elif [[ $prev == "resolved" ]]; then
			COMPREPLY=( $(compgen -W "sync" -- "${cur}") )
		elif [[ $prev == "to-staging" ]]; then
			COMPREPLY=( $(compgen -W "-m" -- "${cur}") )
		elif [[ $prev == "sync" && $cword == 3 ]]; then
			COMPREPLY=( $(compgen -W "-m" -- "${cur}") )
		fi

		return 0
	}

	complete -F _completion -o filenames gitflow /usr/local/bin/gitflow
