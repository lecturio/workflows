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

# Getting off the ticket branch is a precondition, not a courtesy: git refuses
# to delete the branch that is checked out, and the remote copy is deleted
# first.
emitgit_checkout "$WF_PROD_BRANCH"

#
# The ticket's branches, matched as "git branch | grep -w" did: the ticket as a
# whole word inside the branch name, so ABC-123 takes its ABC-123-track-N
# bookmarks with it. Names are read through for-each-ref, which prints them
# bare - "git branch" marks the checked-out branch with "* ", and that marker
# used to glob-expand against the repository root, so a root holding files
# named master and staging turned them into branches to delete. The remote list
# is origin's alone, without its symbolic origin/HEAD, and the deployed
# branches are dropped from both lists whatever the ticket matches.
#
# The name is cut to the branch by component count and not by "refname:short",
# which shortens only as far as stays unambiguous: a local branch named
# origin/ABC-123 makes short print heads/origin/ABC-123 for it and
# remotes/origin/ABC-123 for the remote-tracking branch, and neither of those
# is a branch git will delete. Trimming the prefix as text has the same flaw in
# reverse - it turns a local origin/ABC-123 into the ABC-123 next to it.
#
# $1 - "remote" for origin's branches, the local ones without it
# Fills WF_DELETE with the matched names, remote ones without the "origin/".
#
__collect_ticket_branches() {
	local REFS="refs/heads" STRIP=2 NAME
	if [ "$1" == "remote" ]; then
		REFS="refs/remotes/origin"
		STRIP=3
	fi

	WF_DELETE=()
	while read -r NAME; do
		if [ "$NAME" == "$WF_PROD_BRANCH" ] || [ "$NAME" == "$WF_STAGING_BRANCH" ]; then
			continue
		fi
		WF_DELETE+=("$NAME")
	done < <(git for-each-ref --format="%(refname:lstrip=$STRIP) %(symref)" "$REFS" |
		awk '$2 == "" { print $1 }' | grep -Fw -- "$WF_TASK")
}

#
# How many commits the branch has that production has not. Compared by patch
# through "git cherry" and not by SHA: the ticket branch is rebased onto
# production before it lands there, so its bookmarks hold the pre-rebase
# commits and every one of them would otherwise read as unmerged. Production is
# origin's copy, because an unpushed local production is exactly the case worth
# asking about.
#
# Everything it cannot vouch for counts as unmerged, since the answer decides
# whether work is deleted unasked. "git cherry" walks past merge commits, and a
# merge can carry a resolution that is in neither of its parents, so those are
# counted on their own; and a comparison that fails at all is worth one, rather
# than the zero a discarded error used to read as.
#
# $1 - branch name
# $2 - "remote" to weigh origin's copy of it
#
__unmerged_commits() {
	local REF="$1" PICKED MERGES
	if [ "$2" == "remote" ]; then
		REF="origin/$1"
	fi

	PICKED=`git cherry "origin/$WF_PROD_BRANCH" "$REF" 2>&1`
	if [ $? -gt 0 ]; then
		echo 1
		return
	fi

	MERGES=`git rev-list --count --merges "origin/$WF_PROD_BRANCH..$REF" 2>/dev/null`
	echo $(( `printf '%s\n' "$PICKED" | grep -c '^+'` + ${MERGES:-1} ))
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

# Origin first, and a refusal there - a protected-ref rule, a lost race - ends
# the run with the local branches still in place, which is the state you can
# re-run from. The other order leaves the work only on a remote that just said
# no.
if [ ${#REMOTE_BRANCHES[@]} -gt 0 ]; then
	gitrun_failonerror push origin --delete "${REMOTE_BRANCHES[@]}"
fi
if [ ${#LOCAL_BRANCHES[@]} -gt 0 ]; then
	gitrun_failonerror branch -D "${LOCAL_BRANCHES[@]}"
fi
