#!/bin/bash

#
# One shot: cherry-pick the ticket commits staging has not seen yet, commit them
# with a message naming those commits, and bookmark how far staging has caught
# up. Conflicts fail the stage without committing anything.
#

WF_ARGC=$#
MSG_FILE=""
trap 'if [ -n "$MSG_FILE" ]; then rm -f "$MSG_FILE"; fi' EXIT

#
# This stage takes no option. -m lands in the same slot, so the message forms
# workflow.sh parses are the only words allowed to follow it, and an attached
# form carries its message inside that one word: nothing may come after it.
#
function require_no_option() {
	local ALLOWED=0

	case "$WF_ENV" in
		"")
			[ "$WF_ARGC" -le 2 ] && ALLOWED=1
			;;
		-m | --message)
			# the message follows, and every word after it belongs to it
			ALLOWED=1
			;;
		-m* | --message=*)
			# an empty value (-m, --message=) is allowed through so the check
			# below can say a message is missing rather than call it an option
			[ "$WF_ARGC" -le 3 ] && ALLOWED=1
			;;
	esac

	if [ $ALLOWED -eq 0 ]; then
		WF_STATUS=1
		print_err "to-staging takes no option other than -m: gitflow $WF_TASK to-staging [-m \"message\"]"
		print_build_msg
		exit 1
	fi

	MESSAGE="`trim_whitespace "$MESSAGE"`"

	# -m with nothing after it, or nothing but spaces, would quietly fall back
	# to the generated message, which is not what someone who typed -m asked
	# for. git would not keep it either: it strips a blank subject line, and the
	# first line of the generated body would end up as the subject instead.
	if [[ -n "$WF_ENV" && -z "$MESSAGE" ]]; then
		WF_STATUS=1
		print_err "$WF_ENV needs a message: gitflow $WF_TASK to-staging -m \"message\""
		print_msg "Leave it out to let the stage name the commits it picked"
		print_build_msg
		exit 1
	fi
}

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
# What to say about a cherry-pick that is not this ticket's: nothing this stage
# offers can finish it, so it stays with git and with whoever started it.
#
function print_foreign_pick_advice() {
	local STOPPED="`stopped_on_commit`"

	if [ -n "$STOPPED" ]; then
		print_msg "It is applying $STOPPED, which is not part of $WF_TASK"
	else
		print_msg "It is not applying anything from $WF_TASK"
	fi

	# what is left to do depends on where the pick stands: with nothing staged
	# there is nothing to add or commit, and git commit would fail
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
	print_msg "Then run to-staging again"
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
# Unlike "resolved", this stage commits without a stop for review, so it must
# not fold anything of yours into the staging commit, and it must not throw away
# an operation somebody is in the middle of.
#
function require_clean_start() {
	local BRANCH="`git rev-parse --abbrev-ref HEAD`"
	local OP="`in_flight_operation`"
	local QUEUED="`pending_pick_count`"
	local LATER=$(( QUEUED - 1 ))
	local A="A"

	if [ "$OP" == "am" ]; then
		A="An"
	fi

	# A rebase in flight leaves HEAD detached, and "on HEAD" reads like a branch
	if [ "$BRANCH" == "HEAD" ]; then
		BRANCH="a detached HEAD"
	fi

	# Unresolved conflicts, from whichever operation left them. A rebase or a
	# merge is not something this stage can advise on: pointing at
	# "resolved sync" there would commit somebody else's resolution onto
	# staging and bookmark it as if it were the ticket.
	if [ -n "`git ls-files -u`" ]; then
		WF_STATUS=1
		if [ "$OP" == "cherry-pick" ]; then
			print_err "A cherry-pick with unresolved conflicts is in progress on $BRANCH"
			if [ -n "`queue_belongs_to_ticket`" ]; then
				print_conflict_recovery "$QUEUED"
				print_msg "Or drop it: git cherry-pick --abort"
			else
				print_foreign_pick_advice unresolved
			fi
		elif [ -n "$OP" ]; then
			print_err "$A $OP with unresolved conflicts is in progress on $BRANCH"
			print_msg "Finish it, or abandon it with git $OP --abort, then run to-staging again"
		else
			print_err "$BRANCH has unresolved conflicts"
			print_msg "Resolve or discard them, then run to-staging again"
		fi
		print_build_msg
		exit 1
	fi

	# The conflicts are resolved but the operation itself is still open, and
	# git is the only thing that can carry it to the end. This has to be asked
	# before the worktree is judged dirty: a resolution that is staged looks
	# exactly like local changes of your own, and "commit or stash" is the one
	# thing you must not do in the middle of a rebase.
	case "$OP" in
		rebase | merge | revert | am)
			WF_STATUS=1
			print_err "$A $OP is in progress on $BRANCH"
			print_msg "Finish it, or abandon it with git $OP --abort, then run to-staging again"
			print_build_msg
			exit 1
			;;
	esac

	# A cherry-pick run without -n records CHERRY_PICK_HEAD and keeps it until
	# the commit is made, so this is a pick paused with its conflicts already
	# resolved - "all conflicts fixed: run git cherry-pick --continue". The
	# stage's own picks never set it, so this is somebody's work by hand.
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
		if [ -z "`queue_belongs_to_ticket`" ]; then
			print_foreign_pick_advice staged
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
	# One queued commit is that one: state git leaves behind, which blocks the
	# next cherry-pick and is cleared with --quit, keeping the index. More than
	# one means commits are still waiting, and only "git cherry-pick --continue"
	# can apply them: quitting would drop them from the queue, and the next run
	# would start the whole range again and collide with the resolution that is
	# already there.
	if [ "$QUEUED" -gt 1 ]; then
		WF_STATUS=1
		print_err "A cherry-pick on $BRANCH still has $LATER commit(s) to apply"
		if [ -z "`queue_belongs_to_ticket`" ]; then
			print_foreign_pick_advice clean
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

	if [ -n "$DIRTY" ]; then
		WF_STATUS=1
		print_err "Commit or stash your local changes before to-staging"
		print_msg "It commits to $WF_STAGING_BRANCH without a review stop, so it refuses to sweep them in"
		print_build_msg
		exit 1
	fi

	if [ "$QUEUED" -gt 0 ]; then
		emit "git cherry-pick --quit" quiet
	fi
}

#
# Nobody writes these messages by hand, so name the commits that went in:
# "ABC-123 a1b2c3d 4e5f6a7", or your -m text with the commits underneath.
#
function write_commit_message() {
	MSG_FILE=`mktemp "${TMPDIR:-/tmp}/gitflow-msg.XXXXXX"`

	if [ "$MESSAGE" == "" ]; then
		printf '%s %s\n' "$WF_TASK" "$SHA_LINE" > "$MSG_FILE"
	else
		printf '%s\n\n' "$MESSAGE" > "$MSG_FILE"
		git log --reverse --format='%h %s' "$RANGE" >> "$MSG_FILE"
	fi
}

#
# Report the conflict and leave it alone: the sequencer's todo names the commit
# that stopped us and everything still queued behind it.
#
function fail_on_conflict() {
	WF_STATUS=1
	print_err "Cherry-pick onto $WF_STAGING_BRANCH conflicts - nothing was committed"

	local STOPPED="`stopped_on_commit`"
	if [ -n "$STOPPED" ]; then
		print_msg "Stopped on $STOPPED"
	fi

	print_conflict_recovery "`pending_pick_count`"
	print_msg "Or start over with: git cherry-pick --abort"

	print_build_msg
	exit 1
}

#
# The cherry-pick failed without leaving a conflict behind, so git has already
# printed the reason - a merge commit in the range is the usual one, since
# cherry-pick will not apply one without being told which side to keep.
# Whatever applied before it is staged, and committing that would put half a
# range on staging under a bookmark claiming all of it, so the way out is to
# throw it away rather than to sync it.
#
function fail_on_pick_error() {
	WF_STATUS=1
	print_err "Cherry-pick onto $WF_STAGING_BRANCH failed - git's reason is above"
	print_msg "Nothing was committed and no bookmark was made"

	if [ -n "`git log --merges --format=%h -1 "$RANGE"`" ]; then
		print_msg "$RANGE holds a merge commit, which cherry-pick cannot apply"
	fi

	print_msg "Throw away what did apply with: git cherry-pick --abort"

	print_build_msg
	exit 1
}

require_no_option
emit_failonerror_pending_commits "$WF_TASK"
require_clean_start

refresh_origin
require_origin_branch "$WF_PROD_BRANCH"
require_origin_branch "$WF_STAGING_BRANCH"
setup_branch "$WF_PROD_BRANCH" && setup_branch "$WF_TASK" && setup_branch "$WF_STAGING_BRANCH"

RANGE="`cherry_pick_range`"
SHA_LINE="`trim_whitespace "$(git log --reverse --format='%h' "$RANGE" | tr '\n' ' ')"`"

if [ "$SHA_LINE" == "" ]; then
	print_msg "$WF_STAGING_BRANCH is already level with $WF_TASK - nothing to cherry-pick"
	print_build_msg
	exit 0
fi

print_msg "Cherry-picking $RANGE onto $WF_STAGING_BRANCH"
emit "git cherry-pick -Xignore-all-space -n $RANGE"
PICK_STATUS=$?

if [ -n "`git ls-files -u`" ]; then
	fail_on_conflict
elif [ $PICK_STATUS -gt 0 ]; then
	fail_on_pick_error
fi

if git diff --cached --quiet; then
	print_msg "$WF_STAGING_BRANCH already carries $SHA_LINE - bookmarking without a commit"
else
	write_commit_message
	emit_failonerror "git commit -F \"$MSG_FILE\"" print_msg
	print_msg "Committed on $WF_STAGING_BRANCH: `git log --format='%h %s' -1`"
fi

track_feature_branch
setup_branch "$WF_STAGING_BRANCH"

if [[ $WF_STATUS -eq 0 &&
	-n "`git log --oneline origin/$WF_STAGING_BRANCH..$WF_STAGING_BRANCH`" ]]; then
	print_msg "Now push it: git push origin $WF_STAGING_BRANCH"
fi
