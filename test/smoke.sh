#!/bin/bash
#
# The flow end to end against throwaway repositories: in-progress, pr,
# to-staging, deployable and closed, each checked for the exit status its
# banner promises and for what it left behind. There is no framework here on
# purpose - a stage is run, and what it did is looked at.
#
# Your own clones are never touched. The project, its origin and a copy of the
# tool are built under a temporary directory; HOME, TMPDIR and PATH point into
# it, and it goes away when the run ends. "readlink" and "ssh" are stubbed:
# the first so the run does not follow an installed symlink out of the copy
# under test, the second because a project whose origin is a path has no
# github.com key to offer.
#
# Usage: test/smoke.sh [path to a gitflow clone]   default: the one this is in
#

TOOL_SRC="${1:-`cd "$(dirname "$0")/.." && pwd`}"
FAILURES=0

ROOT=`mktemp -d "${TMPDIR:-/tmp}/gitflow-smoke.XXXXXX"` || exit 1
trap 'rm -rf "$ROOT"' EXIT

#
# $1 - what was checked, $2 - what it should be, $3 - what it was
#
check() {
	if [ "$2" == "$3" ]; then
		echo "ok    $1"
	else
		echo "FAIL  $1: expected \"$2\", got \"$3\""
		FAILURES=$((FAILURES + 1))
	fi
}

#
# Run a stage, keeping its output and status for the checks that follow.
#
stage() {
	OUT=`bash "$ROOT/tool/workflow.sh" "$@" 2>&1`
	STATUS=$?
}

says() {
	case "$OUT" in
		*"$1"*) echo yes ;;
		*) echo no ;;
	esac
}

git_t() {
	git -c user.email=smoke@test -c user.name=smoke "$@"
}

mkdir -p "$ROOT/tool" "$ROOT/bin" "$ROOT/home" "$ROOT/tmp"

#
# Everything below runs against this environment, the repositories built here
# included: with your own HOME in place they would be created under your git
# configuration, and a "commit.gpgSign" or a "core.hooksPath" of yours would
# reach into a fixture that has nothing to do with them. The two branch names
# are unset for the same reason - the tool reads them from the environment when
# a project has no .gitflow, and a shell holding "main" would send these stages
# looking for branches this fixture never creates.
#
export HOME="$ROOT/home"
export TMPDIR="$ROOT/tmp"
export PATH="$ROOT/bin:$PATH"
unset WF_PROD_BRANCH WF_STAGING_BRANCH

# a copy of the tool, with an origin of its own so the update check passes
tar -C "$TOOL_SRC" --exclude=.git -cf - . | tar -C "$ROOT/tool" -xf - || exit 1
git init -qb master "$ROOT/tool"
git -C "$ROOT/tool" add -A
git_t -C "$ROOT/tool" commit -qm "tool under test"
git init -qb master --bare "$ROOT/tool-origin"
git -C "$ROOT/tool" remote add origin "$ROOT/tool-origin"
git -C "$ROOT/tool" push -q -u origin master

printf '#!/bin/bash\nexit 1\n' > "$ROOT/bin/readlink"
printf '#!/bin/bash\nexit 1\n' > "$ROOT/bin/ssh"
chmod +x "$ROOT/bin/readlink" "$ROOT/bin/ssh"

# the project: production and staging, one commit on each
git init -qb master --bare "$ROOT/origin"
git clone -q "$ROOT/origin" "$ROOT/proj" 2>/dev/null   # an empty origin says so
cd "$ROOT/proj" || exit 1
git config user.email smoke@test
git config user.name smoke
echo base > shared.txt
git add -A
git commit -qm base
git push -q -u origin master
git checkout -qb staging
git push -q -u origin staging
git checkout -q master


stage ABC-123 in-progress
check "in-progress exits 0" 0 "$STATUS"
check "in-progress reports success" yes "`says 'BUILD SUCCESS'`"
check "in-progress leaves you on the ticket" ABC-123 "`git rev-parse --abbrev-ref HEAD`"
check "in-progress pushes the ticket" 0 "`git rev-parse -q --verify origin/ABC-123 >/dev/null; echo $?`"

echo work >> shared.txt
git commit -qam "the work"
git push -q origin ABC-123

# an origin that is not github.com: pr has nothing to print, and says so
stage ABC-123 pr
check "pr refuses an origin that is not github" 1 "$STATUS"
check "pr reports the failure" yes "`says 'BUILD FAILURE'`"

stage ABC-123 to-staging -m "sync it"
check "to-staging exits 0" 0 "$STATUS"
check "to-staging reports success" yes "`says 'BUILD SUCCESS'`"
check "to-staging commits the pick" "sync it" "`git log -1 --format=%s staging`"
check "to-staging leaves nothing staged" "" "`git status --porcelain`"

stage ABC-123 to-staging
check "a second to-staging exits 0" 0 "$STATUS"
check "a second to-staging picks nothing" "sync it" "`git log -1 --format=%s staging`"

# a ticket origin has never heard of is refused rather than guessed at
stage TYPO-999 to-staging
check "to-staging refuses an unknown ticket" 1 "$STATUS"

git checkout -q ABC-123
stage ABC-123 deployable
check "deployable exits 0" 0 "$STATUS"
check "deployable reports success" yes "`says 'BUILD SUCCESS'`"
check "deployable puts the work on production" "the work" "`git log -1 --format=%s master`"
git push -q origin master

stage ABC-123 closed
check "closed exits 0" 0 "$STATUS"
check "closed reports success" yes "`says 'BUILD SUCCESS'`"
check "closed deletes the ticket locally" 1 "`git rev-parse -q --verify ABC-123 >/dev/null; echo $?`"
check "closed deletes the ticket on origin" 1 "`git rev-parse -q --verify origin/ABC-123 >/dev/null; echo $?`"

stage ABC-123 nonsense
check "an unknown stage is refused" 1 "$STATUS"

#
# A stage that fails partway and runs on to the end, which every other refusal
# here does not: they exit where they happen. Without a fetch refspec the push
# lands but no tracking ref follows it, so "git branch -u" fails and the pull
# after it works - the shape that reported BUILD SUCCESS while the upstream it
# had just failed to set was missing. Both halves of the answer are checked,
# since a status that is assigned rather than raised loses the failure, and a
# run that ends without "exit $WF_STATUS" loses it just as well.
#
git config --unset remote.origin.fetch
stage XYZ-777 in-progress
check "a failure partway through a stage is still reported" yes "`says 'BUILD FAILURE'`"
check "a failure partway through a stage still exits non-zero" 1 "$STATUS"

check "no commit message file is left behind" 0 "`ls "$TMPDIR" | grep -c gitflow-msg`"

echo
if [ $FAILURES -eq 0 ]; then
	echo "smoke: everything checked out"
else
	echo "smoke: $FAILURES check(s) failed"
fi
exit $FAILURES
