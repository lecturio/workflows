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
	if [ -n "`git ls-files -u`" ]; then
		WF_STATUS=1
		print_err "A cherry-pick with unresolved conflicts is in progress on `git rev-parse --abbrev-ref HEAD`"
		print_msg "Finish it: fix the files, git add them, then gitflow $WF_TASK resolved sync -m \"message\""
		print_msg "Or drop it: git cherry-pick --abort"
		print_build_msg
		exit 1
	fi

	if [ -n "`git status --porcelain --untracked-files=no`" ]; then
		WF_STATUS=1
		print_err "Commit or stash your local changes before to-staging"
		print_msg "It commits to $WF_STAGING_BRANCH without a review stop, so it refuses to sweep them in"
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
		print_err "A cherry-pick on `git rev-parse --abbrev-ref HEAD` still has $QUEUED commit(s) to apply"
		print_msg "Apply them: git cherry-pick --continue   # repeat per conflict"
		print_msg "Then commit anything it leaves staged: gitflow $WF_TASK resolved sync -m \"message\""
		print_msg "Or give up on the rest: git cherry-pick --abort"
		print_build_msg
		exit 1
	fi

	if [[ "$QUEUED" -gt 0 ]] ||
		git rev-parse -q --verify CHERRY_PICK_HEAD >/dev/null 2>&1; then
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

if [[ $PICK_STATUS -gt 0 || -n "`git ls-files -u`" ]]; then
	fail_on_conflict
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

if [ $WF_STATUS -eq 0 ]; then
	print_msg "Now push it: git push origin $WF_STAGING_BRANCH"
fi
