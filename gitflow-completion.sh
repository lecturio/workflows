#!/bin/bash

#
# What a run would use for one of the deployed branches: the environment, or the
# project's .gitflow, which overrides it. Read here the way load_gitflow reads
# it - the key, optional spaces around the "=", optional quotes - so the ticket
# slot hides the same two names the stages refuse, whatever a project calls
# them. Nothing is eval'd: the file is the project's, not ours.
# $1 - key, $2 - the tool's default for it
#
_gitflow_deployed_branch() {
	local ROOT LINE VALUE="${!1:-$2}"

	ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
	if [ -n "$ROOT" ] && [ -f "$ROOT/.gitflow" ]; then
		while IFS= read -r LINE || [ -n "$LINE" ]; do
			if [[ "$LINE" =~ ^[[:space:]]*$1[[:space:]]*=[[:space:]]*(.*)$ ]]; then
				VALUE="${BASH_REMATCH[1]%$'\r'}"
				VALUE="${VALUE%"${VALUE##*[![:space:]]}"}"
				case "$VALUE" in
					\"*\") VALUE="${VALUE#\"}"; VALUE="${VALUE%\"}" ;;
					\'*\') VALUE="${VALUE#\'}"; VALUE="${VALUE%\'}" ;;
				esac
			fi
		done < "$ROOT/.gitflow"
	fi

	printf '%s' "$VALUE"
}

#
# Branch names for the ticket slot, one to a line and undecorated. Read through
# for-each-ref, as "closed" reads them: "git branch" decorates its output with
# a "* " in front of the checked-out branch, which compgen word-splits and
# globs - in a repository root holding a file named README.md, tab offered
# README.md as a ticket - and in detached HEAD it adds a line of its own,
# "(HEAD detached at 1a2b3c4)", whose four words were offered as four tickets.
# --format alone fixes the marker but not that line, which is not a ref at all.
# lstrip=2 leaves a local branch bare and a remote one as "origin/ABC-123",
# which is what you type. Production and staging are left out: they are exactly
# the names "closed" refuses, and neither is a ticket. So is origin/HEAD, which
# is a symref onto production rather than a branch anybody works on.
# $1 - "remote" for origin's branches, nothing for the local ones
#
_gitflow_ticket_branches() {
	local NAME SYMREF PREFIX="" REFS="refs/heads" PROD STAGING
	if [ "$1" == "remote" ]; then
		PREFIX="origin/"
		REFS="refs/remotes/origin"
	fi

	PROD="$(_gitflow_deployed_branch WF_PROD_BRANCH master)"
	STAGING="$(_gitflow_deployed_branch WF_STAGING_BRANCH staging)"

	git for-each-ref --format='%(refname:lstrip=2) %(symref)' "$REFS" 2>/dev/null |
	while read -r NAME SYMREF; do
		if [ -n "$SYMREF" ]; then
			continue
		fi
		if [ "$NAME" == "$PREFIX$PROD" ] || [ "$NAME" == "$PREFIX$STAGING" ]; then
			continue
		fi
		printf '%s\n' "$NAME"
	done
}

_completion() {
	local cur prev opts
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"
	let cword=COMP_CWORD-1
	opts="in-progress to-staging resolved deployable closed pr"
	self_opts="update"

	if [[ ${cword} -eq 0 ]]; then
		if [[ $cur == *origin* ]]; then
			COMPREPLY=( $(compgen -W "$(_gitflow_ticket_branches remote)" -- "${cur}") )
		else
			COMPREPLY=( $(compgen -W "$(_gitflow_ticket_branches) origin/ self" -- "${cur}") )
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
