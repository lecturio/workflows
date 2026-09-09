#!/bin/bash

#
# One shot: cherry-pick the ticket commits staging has not seen yet, commit them
# with a message naming those commits, and bookmark how far staging has caught
# up. Conflicts fail the stage without committing anything.
#

MSG_FILE=""
trap 'if [ -n "$MSG_FILE" ]; then rm -f "$MSG_FILE"; fi' EXIT

#
# This stage takes no option. -m lands in the same slot, so the message forms
# workflow.sh parses are the only words allowed to follow it.
#
function require_no_option() {
	case "$WF_ENV" in
		"" | -m | -m?* | --message | --message=?*)
			;;
		*)
			WF_STATUS=1
			print_err "to-staging takes no option other than -m: gitflow $WF_TASK to-staging [-m \"message\"]"
			print_build_msg
			exit 1
			;;
	esac
}

#
# Which git operation this repository has paused, if any. Each one leaves its
# own marker, and only a cherry-pick is something "resolved sync" can finish.
#
function in_flight_operation() {
	if [[ -d "`git rev-parse --git-path rebase-merge`" ||
		-d "`git rev-parse --git-path rebase-apply`" ]]; then
		echo rebase
	elif git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
		echo merge
	elif git rev-parse -q --verify REVERT_HEAD >/dev/null 2>&1; then
		echo revert
	elif [[ -d "`git rev-parse --git-path sequencer`" ]] ||
		git rev-parse -q --verify CHERRY_PICK_HEAD >/dev/null 2>&1; then
		echo cherry-pick
	fi
}

#
# How many commits the in-flight cherry-pick still has queued, the one it
# stopped on included. Zero when no sequencer state is lying around.
#
function pending_pick_count() {
	local TODO="`git rev-parse --git-path sequencer`/todo"

	if [ -f "$TODO" ]; then
		grep -c '^pick ' "$TODO"
	else
		echo 0
	fi
}

#
# Unlike "resolved", this stage commits without a stop for review, so it must
# not fold anything of yours into the staging commit, and it must not throw away
# a conflict resolution someone is in the middle of.
#
function require_clean_start() {
	local BRANCH="`git rev-parse --abbrev-ref HEAD`"
	local OP="`in_flight_operation`"

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
			print_msg "Finish it: fix the files, git add them, then gitflow $WF_TASK resolved sync -m \"message\""
			print_msg "Or drop it: git cherry-pick --abort"
		elif [ -n "$OP" ]; then
			print_err "A $OP with unresolved conflicts is in progress on $BRANCH"
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
		rebase | merge | revert)
			WF_STATUS=1
			print_err "A $OP is in progress on $BRANCH"
			print_msg "Finish it, or abandon it with git $OP --abort, then run to-staging again"
			print_build_msg
			exit 1
			;;
	esac

	# A cherry-pick run without -n records CHERRY_PICK_HEAD and keeps it until
	# the commit is made, so this is a pick that is paused with its conflicts
	# already resolved - "all conflicts fixed: run git cherry-pick --continue".
	# The stage's own picks never set it, so this is somebody's work by hand.
	if git rev-parse -q --verify CHERRY_PICK_HEAD >/dev/null 2>&1; then
		WF_STATUS=1
		print_err "A cherry-pick is paused on $BRANCH with its conflicts already resolved"
		print_msg "Finish it: git cherry-pick --continue"
		print_msg "Or drop it: git cherry-pick --abort"
		print_build_msg
		exit 1
	fi

	# The worktree is clean, so whatever cherry-pick is in flight had its
	# conflict resolved and committed by hand. One queued commit is the one that
	# was resolved: state git leaves behind, which blocks the next cherry-pick
	# and is cleared with --quit, keeping the index. More than one means commits
	# are still waiting, and only "git cherry-pick --continue" can apply them:
	# quitting would drop them from the queue, and the next run would start the
	# whole range again and collide with the resolution that is already there.
	local QUEUED="`pending_pick_count`"

	if [ "$QUEUED" -gt 1 ]; then
		WF_STATUS=1
		let "QUEUED=QUEUED-1"
		print_err "A cherry-pick on $BRANCH still has $QUEUED commit(s) to apply"
		print_msg "Apply them: git cherry-pick --continue   # repeat per conflict"
		print_msg "Then commit anything it leaves staged: gitflow $WF_TASK resolved sync -m \"message\""
		print_msg "Or give up on the rest: git cherry-pick --abort"
		print_build_msg
		exit 1
	fi

	local DIRTY="`git status --porcelain --untracked-files=no`"

	# One queued commit and something staged is the wreckage of a cherry-pick
	# that stopped without conflicting - a merge commit in the range does this.
	# What is staged is part of a range, so committing it would put half of one
	# on staging: say so instead of asking for a commit.
	if [[ "$QUEUED" -gt 0 && -n "$DIRTY" ]]; then
		WF_STATUS=1
		print_err "A cherry-pick left part of a range staged on $BRANCH"
		print_msg "Committing it would put half a range on $WF_STAGING_BRANCH"
		print_msg "Throw it away with: git cherry-pick --abort"
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
	local TODO="`git rev-parse --git-path sequencer`/todo"
	local PENDING="`pending_pick_count`"

	WF_STATUS=1
	print_err "Cherry-pick onto $WF_STAGING_BRANCH conflicts - nothing was committed"

	if [ -f "$TODO" ]; then
		print_msg "Stopped on `sed -n 's/^pick //p' "$TODO" | head -1`"
	fi

	print_msg "Fix the conflicted files and \"git add\" them, then:"
	if [ "$PENDING" -gt 1 ]; then
		let "PENDING=PENDING-1"
		print_msg "  git commit && git cherry-pick --continue     # $PENDING more commit(s) to apply, repeat per conflict"
		print_msg "  git status                                   # -n leaves the ones that applied cleanly staged"
		print_msg "  gitflow $WF_TASK resolved sync -m \"message\"   # commits what is staged, then bookmarks"
	else
		print_msg "  gitflow $WF_TASK resolved sync -m \"message\"   # commits and bookmarks"
	fi
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
