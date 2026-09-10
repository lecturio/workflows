#!/bin/bash
# What git has paused in this repository, and what to say about it
#
# Three stages apply commits somewhere - to-staging and resolved cherry-pick
# onto staging, deployable rebases - and none of them may run over an operation
# that is already open, or clear one it did not create. A conflict resolution is
# work by hand that nothing can reproduce, and the marker files say only what
# git is in the middle of, never who started it or why. So every stage asks the
# same questions here and refuses on the answer, rather than each carrying its
# own idea of what "in flight" means.

#
# The verb the paused sequencer is working through. A cherry-pick and a revert
# of several commits both run through it, and the todo is what tells them apart.
#
function sequencer_verb() {
	local TODO="`git rev-parse --git-path sequencer`/todo"

	if [ -f "$TODO" ]; then
		sed -n '1s/^\([a-z][a-z]*\).*/\1/p' "$TODO"
	fi
}

#
# Which git operation this repository has paused, if any. Each one leaves its
# own marker, and only a cherry-pick is something "resolved sync" can finish.
#
function in_flight_operation() {
	if [ -f "`git rev-parse --git-path rebase-apply/applying`" ]; then
		# git am keeps its state in rebase-apply too, and only this marker
		# separates the two: "git rebase --abort" is not the way out of an am
		echo am
	elif [[ -d "`git rev-parse --git-path rebase-merge`" ||
		-d "`git rev-parse --git-path rebase-apply`" ]]; then
		echo rebase
	elif git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
		echo merge
	elif git rev-parse -q --verify REVERT_HEAD >/dev/null 2>&1; then
		echo revert
	elif [[ -d "`git rev-parse --git-path sequencer`" ]] ||
		git rev-parse -q --verify CHERRY_PICK_HEAD >/dev/null 2>&1; then
		# Once a conflicted revert is committed by hand REVERT_HEAD is gone
		# while its queue remains, so the sequencer directory on its own would
		# read as a cherry-pick and this stage would name the wrong operation.
		if [ "`sequencer_verb`" == "revert" ]; then
			echo revert
		else
			echo cherry-pick
		fi
	fi
}

#
# How many commits the paused sequencer still has queued, the one it stopped on
# included. Zero when no sequencer state is lying around.
#
function pending_pick_count() {
	local TODO="`git rev-parse --git-path sequencer`/todo"

	if [ -f "$TODO" ]; then
		grep -c '^\(pick\|revert\) ' "$TODO"
	else
		echo 0
	fi
}

#
# "<short sha> <subject>" of the commit the sequencer stopped on.
#
function stopped_on_commit() {
	local TODO="`git rev-parse --git-path sequencer`/todo"

	if [ -f "$TODO" ]; then
		sed -n '1s/^[a-z][a-z]* //p' "$TODO"
	fi
}

#
# Whether it stopped on a merge commit. cherry-pick will not apply one, and
# that failure leaves a staged partial range behind, which otherwise looks
# exactly like a conflict someone resolved and has not committed yet.
#
function stopped_on_merge() {
	local TODO="`git rev-parse --git-path sequencer`/todo"
	local SHA=

	if [ -f "$TODO" ]; then
		SHA=`sed -n '1s/^[a-z][a-z]* \([0-9a-f][0-9a-f]*\).*/\1/p' "$TODO"`
	fi

	if [[ -n "$SHA" ]] && git rev-parse -q --verify "$SHA^2" >/dev/null 2>&1; then
		echo yes
	fi
}

#
# Whether the paused cherry-pick is this ticket's own sync. One found in the
# preflight can belong to another ticket, and naming this ticket's "resolved
# sync" there would commit somebody else's work onto staging and bookmark this
# ticket as synced when none of its commits went in - which the next sync then
# skips for good. A sync of this ticket runs on staging and works through exactly
# the commits of its range, so the branch and the whole of that range decide it.
# Ancestry is not enough - every commit of production is an ancestor of the ticket
# branch - and neither is one queued commit falling inside the range, since a pick
# of part of the range would bookmark past the part nobody applied.
#
function queue_belongs_to_ticket() {
	local SQ="`git rev-parse --git-path sequencer`"

	if [ "`git rev-parse --abbrev-ref HEAD`" != "$WF_STAGING_BRANCH" ]; then
		return
	fi

	if ! git rev-parse --verify --quiet "$WF_TASK" >/dev/null 2>&1; then
		return
	fi

	local EXPECTED=`git rev-list "$(cherry_pick_range)" 2>/dev/null | sort -u`
	if [ -z "$EXPECTED" ]; then
		return
	fi

	# Everything the sequencer holds, applied and still queued alike. A pick of
	# part of the range is not this sync: finishing it and bookmarking would
	# move the bookmark to the ticket tip while the commits nobody applied stay
	# behind it, and every later sync would skip them.
	local QUEUED_SHAS=`{ sed -n 's/^[a-z][a-z]* \([0-9a-f][0-9a-f]*\).*/\1/p' "$SQ/todo" 2>/dev/null
		sed -n 's/^[a-z][a-z]* \([0-9a-f][0-9a-f]*\).*/\1/p' "$SQ/done" 2>/dev/null; }`
	if [ -z "$QUEUED_SHAS" ]; then
		return
	fi

	local RESOLVED=`for SHA in $QUEUED_SHAS; do git rev-parse -q --verify "${SHA}^{commit}"; done | sort -u`

	if [ "$RESOLVED" == "$EXPECTED" ]; then
		echo yes
	fi
}

#
# The branch the operation sits on, worded for a message: a rebase leaves HEAD
# detached, and "on HEAD" reads like the name of a branch.
#
function in_flight_branch() {
	local BRANCH="`git rev-parse --abbrev-ref HEAD`"

	if [ "$BRANCH" == "HEAD" ]; then
		BRANCH="a detached HEAD"
	fi

	printf '%s' "$BRANCH"
}

#
# "A" or "An" in front of the operation's name.
# $1 - operation
#
function in_flight_article() {
	if [ "$1" == "am" ]; then
		printf 'An'
	else
		printf 'A'
	fi
}

#
# What to say about a cherry-pick the stage cannot carry on with: nothing it
# offers can finish it, so it stays with git and with whoever started it.
# $1 - where the pick stands: unresolved, staged, or anything else for a clean
#      worktree, since with nothing staged there is nothing to add or commit and
#      "git commit" would fail
# $2 - stage name, for the line that says to run it again
# $3 - "foreign" when the pick is not applying this ticket's commits
#
function print_pick_handback() {
	local STOPPED="`stopped_on_commit`"

	if [ "$3" == "foreign" ]; then
		if [ -n "$STOPPED" ]; then
			print_msg "It is applying $STOPPED, which is not part of $WF_TASK"
		else
			print_msg "It is not applying anything from $WF_TASK"
		fi
	elif [ -n "$STOPPED" ]; then
		print_msg "It is applying $STOPPED"
	fi

	case "$1" in
		unresolved)
			print_msg "Fix the files, git add them, git commit, then git cherry-pick --continue"
			;;
		staged)
			print_msg "Commit what is staged, then git cherry-pick --continue"
			;;
		*)
			print_msg "Carry it on with git cherry-pick --continue"
			;;
	esac

	print_msg "Or drop it with git cherry-pick --abort"
	print_msg "Then run $2 again"
}

#
# An operation that is not a cherry-pick. No stage has anything to offer here -
# pointing at "resolved sync" would commit somebody else's resolution onto
# staging - so git carries it to the end, or nothing does.
# $1 - operation
# $2 - stage name
#
function print_op_handback() {
	print_msg "Finish it, or abandon it with git $1 --abort, then run $2 again"
}

#
# The way out of a conflicted cherry-pick, which depends on whether the range
# holds commits after the one that stopped it: --continue keeps the -n the range
# started with, so those apply staged and uncommitted, and a bookmark taken
# before they are committed would claim work that never reached staging.
# $1 - commits still queued, the conflicted one included
#
function print_conflict_recovery() {
	local LATER=$(( $1 - 1 ))

	print_msg "Fix the conflicted files and \"git add\" them, then:"
	if [ "$LATER" -gt 0 ]; then
		print_msg "  git commit && git cherry-pick --continue     # $LATER more commit(s); if one conflicts, fix it, git add, and repeat"
		print_msg "  git status                                   # -n leaves the ones that applied cleanly staged"
		print_msg "  gitflow $WF_TASK resolved sync -m \"message\"   # commits what is staged, then bookmarks"
		print_msg "  gitflow $WF_TASK resolved sync                # instead of the line above when nothing is left staged"
	else
		print_msg "  gitflow $WF_TASK resolved sync -m \"message\"   # commits and bookmarks"
	fi
}

#
# End the run when git has an operation open here, naming it, the branch it is
# on and the way to finish or abandon it. Nothing is aborted, quit or committed:
# a stage that clears state it did not create throws away a resolution somebody
# made by hand, and the markers cannot tell the tool's own leftovers from a
# cherry-pick or a rebase started for a reason of your own.
#
# The operation is named before the worktree is called dirty, because a
# resolution that is staged looks exactly like local changes of your own, and
# "commit or stash" is the one thing not to do in the middle of a rebase.
#
# Sequencer state with nothing left to apply is not covered here: it holds no
# work, and what to do with it differs by stage - to-staging made the pick and
# clears its own, the others say how to clear it.
#
# $1 - stage name, for the messages
# $2 - "own-pick" when a cherry-pick working through this ticket's own sync
#      range is one this stage can name the next step for; without it a pick is
#      handed back to git whoever it belongs to
#
function require_nothing_in_flight() {
	local STAGE="$1"
	local BRANCH="`in_flight_branch`"
	local OP="`in_flight_operation`"
	local QUEUED="`pending_pick_count`"
	local LATER=$(( QUEUED - 1 ))
	local A="`in_flight_article "$OP"`"
	local OWN="" FOREIGN="foreign"

	if [ "$2" == "own-pick" ]; then
		OWN="`queue_belongs_to_ticket`"
	else
		# with no ticket-specific step to offer, saying whose pick it is would
		# be an aside: the answer is git's either way
		FOREIGN=""
	fi

	# Unresolved conflicts, from whichever operation left them. A rebase or a
	# merge is not something these stages can advise on: pointing at
	# "resolved sync" there would commit somebody else's resolution onto
	# staging and bookmark it as if it were the ticket.
	if [ -n "`git ls-files -u`" ]; then
		WF_STATUS=1
		if [ "$OP" == "cherry-pick" ]; then
			print_err "A cherry-pick with unresolved conflicts is in progress on $BRANCH"
			if [ -n "$OWN" ]; then
				print_conflict_recovery "$QUEUED"
				print_msg "Or drop it: git cherry-pick --abort"
			else
				print_pick_handback unresolved "$STAGE" "$FOREIGN"
			fi
		elif [ -n "$OP" ]; then
			print_err "$A $OP with unresolved conflicts is in progress on $BRANCH"
			print_op_handback "$OP" "$STAGE"
		else
			print_err "$BRANCH has unresolved conflicts"
			print_msg "Resolve or discard them, then run $STAGE again"
		fi
		print_build_msg
		exit 1
	fi

	# The conflicts are resolved but the operation itself is still open, and
	# git is the only thing that can carry it to the end.
	case "$OP" in
		rebase | merge | revert | am)
			WF_STATUS=1
			print_err "$A $OP is in progress on $BRANCH"
			print_op_handback "$OP" "$STAGE"
			print_build_msg
			exit 1
			;;
	esac

	# A cherry-pick run without -n records CHERRY_PICK_HEAD and keeps it until
	# the commit is made, so this is a pick paused with its conflicts already
	# resolved - "all conflicts fixed: run git cherry-pick --continue". The
	# stages' own picks never set it, so this is somebody's work by hand.
	if git rev-parse -q --verify CHERRY_PICK_HEAD >/dev/null 2>&1; then
		WF_STATUS=1
		print_err "A cherry-pick is paused on $BRANCH with its conflicts already resolved"
		print_msg "Finish it: git cherry-pick --continue"
		print_msg "Or drop it: git cherry-pick --abort"
		print_build_msg
		exit 1
	fi

	local DIRTY="`git status --porcelain --untracked-files=no`"

	# Stopped on a merge commit, which is a failure and not a conflict: there is
	# nothing here to resolve, and what applied before it is part of a range.
	if [ -n "`stopped_on_merge`" ]; then
		WF_STATUS=1
		print_err "A cherry-pick on $BRANCH stopped on the merge commit `stopped_on_commit`"
		print_msg "cherry-pick cannot apply a merge commit, so this range cannot go through as it stands"
		if [ -n "$DIRTY" ]; then
			print_msg "What did apply is staged, and committing it would put half a range on $WF_STAGING_BRANCH"
		fi
		print_msg "Throw it away with: git cherry-pick --abort"
		print_build_msg
		exit 1
	fi

	# A conflict resolved and staged but never committed. --continue refuses in
	# this state ("your local changes would be overwritten"), so the commit has
	# to come first, whether or not commits are still queued behind it.
	if [[ "$QUEUED" -gt 0 && -n "$DIRTY" ]]; then
		WF_STATUS=1
		print_err "A cherry-pick on $BRANCH has a resolution staged but not committed"
		if [ -z "$OWN" ]; then
			print_pick_handback staged "$STAGE" "$FOREIGN"
			print_build_msg
			exit 1
		fi
		if [ "$LATER" -gt 0 ]; then
			print_msg "Commit it, then apply the $LATER commit(s) still queued:"
			print_msg "  git commit && git cherry-pick --continue     # if one conflicts, fix it, git add, and repeat"
			print_msg "  gitflow $WF_TASK resolved sync -m \"message\"   # commits what is left staged, then bookmarks"
			print_msg "  gitflow $WF_TASK resolved sync                # instead of the line above when nothing is left staged"
		else
			print_msg "Commit it and bookmark the round: gitflow $WF_TASK resolved sync -m \"message\""
		fi
		print_msg "Or drop it: git cherry-pick --abort"
		print_build_msg
		exit 1
	fi

	# The worktree is clean, so the conflict was resolved and committed by hand.
	# More than one commit queued means commits are still waiting, and only
	# "git cherry-pick --continue" can apply them: quitting would drop them from
	# the queue, and the next run would start the whole range again and collide
	# with the resolution that is already there.
	if [ "$QUEUED" -gt 1 ]; then
		WF_STATUS=1
		print_err "A cherry-pick on $BRANCH still has $LATER commit(s) to apply"
		if [ -z "$OWN" ]; then
			print_pick_handback clean "$STAGE" "$FOREIGN"
			print_build_msg
			exit 1
		fi
		print_msg "Apply them: git cherry-pick --continue   # if one conflicts, fix it, git add, and repeat"
		print_msg "Then: gitflow $WF_TASK resolved sync -m \"message\"   # commits what is left staged, then bookmarks"
		print_msg "Or, when nothing is left staged: gitflow $WF_TASK resolved sync"
		print_msg "Or give up on the rest: git cherry-pick --abort"
		print_build_msg
		exit 1
	fi
}

#
# End the run on the state a cherry-pick leaves behind once the commit it
# stopped on has been committed by hand and nothing is queued behind it. There
# is no work in it - "git status" still says "Cherry-pick currently in
# progress", and the next cherry-pick refuses with "cherry-pick is already in
# progress" - but clearing it is a decision, not a tidy-up: "git cherry-pick
# --quit" is the user's to run, and the round it finished may still need its
# bookmark. to-staging is the one stage that clears its own, because it made the
# pick and is about to make the next one.
# $1 - stage name, for the messages
#
function refuse_finished_pick_state() {
	if [ "`pending_pick_count`" -le 0 ]; then
		return 0
	fi

	WF_STATUS=1
	print_err "A cherry-pick on `in_flight_branch` has nothing left to apply and was never cleared"
	print_msg "git counts it as still in progress, and refuses the next cherry-pick while it is there"
	if [ -n "`queue_belongs_to_ticket`" ]; then
		print_msg "It finished a round of $WF_TASK: bookmark that with gitflow $WF_TASK resolved sync"
	fi
	print_msg "Clear what git left with: git cherry-pick --quit   # keeps your index"
	print_msg "Then run $1 again"
	print_build_msg
	exit 1
}
