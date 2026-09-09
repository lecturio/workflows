#!/bin/bash

# The deployed branches are not tickets, and the ticket slot used to take any
# branch name: "gitflow staging closed" removed the shared deploy branch from
# origin and reported BUILD SUCCESS. Tab completion still offers those two
# names, because it completes the slot from "git branch".
if [ "$WF_TASK" == "$WF_PROD_BRANCH" ] || [ "$WF_TASK" == "$WF_STAGING_BRANCH" ]; then
	WF_STATUS=1
	print_err "$WF_TASK is a deployed branch and is never deleted"
	print_build_msg
	exit 1
fi

refresh_origin
require_origin_branch "$WF_PROD_BRANCH"
emit "git checkout $WF_PROD_BRANCH" quiet

#
# The ticket's branches, matched as "git branch | grep -w" did: the ticket as a
# whole word inside the branch name, so ABC-123 takes its ABC-123-track-N
# bookmarks with it. Names are read through for-each-ref, which prints them
# bare - "git branch" marks the checked-out branch with "* ", and that marker
# used to glob-expand against the repository root, so a root holding files
# named master and staging turned them into branches to delete. The remote list
# is origin's alone, without its symbolic origin/HEAD, and the deployed
# branches are dropped from both lists whatever the ticket matches.
# $1 - "remote" for origin's branches, the local ones without it
# Fills WF_DELETE with the matched names, remote ones without the "origin/".
#
__collect_ticket_branches() {
	local REFS="refs/heads" NAME
	if [ "$1" == "remote" ]; then
		REFS="refs/remotes/origin"
	fi

	WF_DELETE=()
	while read -r NAME; do
		NAME="${NAME#origin/}"
		if [ "$NAME" == "$WF_PROD_BRANCH" ] || [ "$NAME" == "$WF_STAGING_BRANCH" ]; then
			continue
		fi
		WF_DELETE+=("$NAME")
	done < <(git for-each-ref --format='%(refname:short) %(symref)' "$REFS" |
		awk '$2 == "" { print $1 }' | grep -Fw -- "$WF_TASK")
}

#
# How many commits the branch has that production has not. Compared by patch
# through "git cherry" and not by SHA: the ticket branch is rebased onto
# production before it lands there, so its bookmarks hold the pre-rebase
# commits and every one of them would otherwise read as unmerged. Production is
# origin's copy, because an unpushed local production is exactly the case worth
# asking about.
# $1 - branch name
# $2 - "remote" to weigh origin's copy of it
#
__unmerged_commits() {
	local REF="$1"
	if [ "$2" == "remote" ]; then
		REF="origin/$1"
	fi

	git cherry "origin/$WF_PROD_BRANCH" "$REF" 2>/dev/null | grep -c '^+'
}

__collect_ticket_branches remote
REMOTE_BRANCHES=("${WF_DELETE[@]}")
__collect_ticket_branches
LOCAL_BRANCHES=("${WF_DELETE[@]}")

UNMERGED=""
for BRANCH in "${LOCAL_BRANCHES[@]}"; do
	if [ "`__unmerged_commits "$BRANCH"`" -gt 0 ]; then
		UNMERGED="$UNMERGED $BRANCH"
	fi
done
for BRANCH in "${REMOTE_BRANCHES[@]}"; do
	if [ "`__unmerged_commits "$BRANCH" remote`" -gt 0 ]; then
		UNMERGED="$UNMERGED origin/$BRANCH"
	fi
done

# Work nobody else has: deleting it is the one step of the flow with no undo.
if [ -n "$UNMERGED" ]; then
	print_msg "Commits not in origin/$WF_PROD_BRANCH:$UNMERGED"

	if [ ! -t 0 ]; then
		WF_STATUS=1
		print_err "Nothing deleted: that needs a confirmation and there is no terminal to ask on"
		print_build_msg
		exit 1
	fi

	printf '[INFO] Delete anyway? [y/N] '
	read -r ANSWER
	if [ "$ANSWER" != "y" ] && [ "$ANSWER" != "Y" ]; then
		WF_STATUS=1
		print_err "Nothing deleted"
		print_build_msg
		exit 1
	fi
fi

if [ ${#REMOTE_BRANCHES[@]} -gt 0 ]; then
	emit "git push origin --delete ${REMOTE_BRANCHES[*]}"
fi
if [ ${#LOCAL_BRANCHES[@]} -gt 0 ]; then
	emit "git branch -D ${LOCAL_BRANCHES[*]}"
fi
