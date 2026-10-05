#!/bin/bash

#
# One shot: cherry-pick the ticket commits staging has not seen yet, commit them
# with a message naming those commits, and bookmark how far staging has caught
# up. Conflicts fail the stage without committing anything, and so does a
# --verify command that fails on the picked tree.
#

WF_ARGC=$#
MSG_FILE=""
trap 'if [ -n "$MSG_FILE" ]; then rm -f "$MSG_FILE"; fi' EXIT

#
# --verify "command" or --verify=command, first after the stage. What follows it
# is read as if the option were not there: nothing, or a message form.
#
VERIFY=""
VERIFY_GIVEN=0
OPT="$WF_ENV"
OPT_POS=3
case "$WF_ENV" in
	--verify)
		VERIFY_GIVEN=1
		VERIFY="$4"
		OPT="$5"
		OPT_POS=5
		;;
	--verify=*)
		VERIFY_GIVEN=1
		VERIFY="${WF_ENV#--verify=}"
		OPT="$4"
		OPT_POS=4
		;;
esac
OPT_ARGC=$((WF_ARGC - OPT_POS + 3))

#
# This stage takes no option but --verify, read above. -m lands in the slot after
# it, or in its place, so the message forms
# workflow.sh parses are the only words allowed to follow it, and an attached
# form carries its message inside that one word: nothing may come after it.
#
function require_no_option() {
	local ALLOWED=0 ARG

	case "$OPT" in
		"")
			[ "$OPT_ARGC" -le 2 ] && ALLOWED=1
			;;
		-m | --message)
			# the message follows, and every word after it belongs to it
			ALLOWED=1
			;;
		-m* | --message=*)
			# an empty value (-m, --message=) is allowed through so the check
			# below can say a message is missing rather than call it an option
			[ "$OPT_ARGC" -le 3 ] && ALLOWED=1
			;;
	esac

	if [ $ALLOWED -eq 0 ]; then
		WF_STATUS=1
		print_err "to-staging takes no option other than --verify and -m: gitflow $WF_TASK to-staging [--verify \"command\"] [-m \"message\"]"
		print_build_msg
		exit 1
	fi

	# -m takes every word after it, so a --verify there would become part of
	# the message and the stage would commit without running it.
	for ARG in "${@:OPT_POS+1}"; do
		case "$ARG" in
			--verify | --verify=*)
				WF_STATUS=1
				print_err "--verify goes before -m: gitflow $WF_TASK to-staging --verify \"command\" -m \"message\""
				print_build_msg
				exit 1
				;;
		esac
	done

	if [[ $VERIFY_GIVEN -eq 1 && -z "`trim_whitespace "$VERIFY"`" ]]; then
		WF_STATUS=1
		print_err "--verify needs a command: gitflow $WF_TASK to-staging --verify \"command\""
		print_build_msg
		exit 1
	fi

	MESSAGE="`trim_whitespace "$MESSAGE"`"

	# -m with nothing after it, or nothing but spaces, would quietly fall back
	# to the generated message, which is not what someone who typed -m asked
	# for. git would not keep it either: it strips a blank subject line, and the
	# first line of the generated body would end up as the subject instead.
	if [[ -n "$OPT" && -z "$MESSAGE" ]]; then
		WF_STATUS=1
		print_err "$OPT needs a message: gitflow $WF_TASK to-staging -m \"message\""
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
		commits_to_pick '%h %s' >> "$MSG_FILE"
	fi
}

#
# The command runs on the picked tree before anything is committed, from the
# top of the clone. When it fails, the pick is reset away and the stage stops
# before the commit and the bookmark, with a status of its own, so a caller can
# tell a failed check from a conflict. Files the command created and git does
# not track are left where it put them.
#
function run_verify() {
	local VERIFY_STATUS=0

	print_msg "Verifying the picked tree: $VERIFY"
	(cd "$WF_GIT_ROOT" && bash -c "$VERIFY") || VERIFY_STATUS=$?

	if [ $VERIFY_STATUS -ne 0 ]; then
		emit_failonerror "git reset -q --hard" quiet
		WF_STATUS=1
		print_err "--verify exited $VERIFY_STATUS: nothing committed, no bookmark, $WF_STAGING_BRANCH left as it was"
		print_build_msg
		exit 3
	fi
	print_msg "Verified: $VERIFY"
}

require_no_option "$@"
emit_failonerror_pending_commits "$WF_TASK"
require_clean_start

refresh_origin
require_origin_branch "$WF_PROD_BRANCH"
require_origin_branch "$WF_STAGING_BRANCH"
setup_branch "$WF_PROD_BRANCH" && setup_branch "$WF_TASK" && setup_branch "$WF_STAGING_BRANCH"
require_staging_checked_out to-staging

require_bookmark_on_branch

RANGE="`cherry_pick_range`"
# The commits themselves rather than the range they were read from: what is
# picked is the range less production's own commits, and handing git the range
# would put those back. Full shas, so nothing here depends on how short a sha
# has to be in this repository to be unambiguous.
PICK_LIST="`trim_whitespace "$(commits_to_pick | tr '\n' ' ')"`"
SHA_LINE="`trim_whitespace "$(commits_to_pick '%h' | tr '\n' ' ')"`"

if [ "$PICK_LIST" == "" ]; then
	print_msg "$WF_STAGING_BRANCH is already level with $WF_TASK - nothing to cherry-pick"
	print_build_msg
	exit 0
fi

print_msg "Cherry-picking $SHA_LINE onto $WF_STAGING_BRANCH"
emit "git cherry-pick -Xignore-all-space -n $PICK_LIST"
PICK_STATUS=$?

if [ -n "`git ls-files -u`" ]; then
	fail_on_conflict
elif [ $PICK_STATUS -gt 0 ]; then
	fail_on_pick_error "$RANGE"
fi

if git diff --cached --quiet; then
	print_msg "$WF_STAGING_BRANCH already carries $SHA_LINE - bookmarking without a commit"
else
	if [ $VERIFY_GIVEN -eq 1 ]; then
		run_verify
	fi
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
