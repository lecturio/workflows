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
# Unlike "resolved", this stage commits without a stop for review, so it must
# not fold anything of yours into the staging commit, and it must not throw away
# an operation somebody is in the middle of. What counts as in flight, and what
# to say about each of them, is shared with the other two stages that apply
# commits - see functions/inflight.sh.
#
function require_clean_start() {
	require_nothing_in_flight to-staging own-pick

	if [ -n "`git status --porcelain --untracked-files=no`" ]; then
		WF_STATUS=1
		print_err "Commit or stash your local changes before to-staging"
		print_msg "It commits to $WF_STAGING_BRANCH without a review stop, so it refuses to sweep them in"
		print_build_msg
		exit 1
	fi

	# Everything above has passed, so a queue that is still here holds exactly
	# the commit whose conflict was resolved and committed by hand: state git
	# leaves behind, which blocks the next cherry-pick and is cleared with
	# --quit, keeping the index. This stage made that pick and is about to make
	# the next one, so it clears its own; --abort, which rewinds, is never run
	# for you.
	if [ "`pending_pick_count`" -gt 0 ]; then
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

require_no_option
emit_failonerror_pending_commits "$WF_TASK"
require_clean_start

refresh_origin
require_origin_branch "$WF_PROD_BRANCH"
require_origin_branch "$WF_STAGING_BRANCH"
setup_branch "$WF_PROD_BRANCH" && setup_branch "$WF_TASK" && setup_branch "$WF_STAGING_BRANCH"
require_staging_checked_out to-staging

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
	fail_on_pick_error "$RANGE"
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
