---
name: gitflow
description: Walk one ticket from a fresh branch to a deployed change with the `gitflow` command and the GitHub CLI - create the ticket branch, open its pull request, cherry-pick it onto staging, merge the pull request into production, delete its branches. Use when asked to start, sync, stage, ship, deploy or close a ticket ("put ABC-123 on staging", "open the PR for ABC-123", "ship ABC-123", "make ABC-123 deployable", "start work on ABC-123", "clean up ABC-123"), whenever a task names a ticket branch together with a stage, and when a staging sync or the merge conflicts and has to be finished by hand.
---

gitflow
=======

`gitflow` runs the git work for one stage of one ticket. Call it from inside the
project clone:

```bash
gitflow <TICKET> <STAGE>
```

`TICKET` is the ticket ID and also the branch name, so `ABC-123` means the branch
`ABC-123`. The project has two deployed branches: **production** (`master` by
default) on the live server, and **staging** (`staging` by default) on the staging
server. A ticket branch is cut from production, pushed onto staging as often as
the review needs, and merged into production through its pull request once it is
accepted.

If the project has a `.gitflow` file at its repository root, read it first — it
renames those two branches (`WF_PROD_BRANCH`, `WF_STAGING_BRANCH`), and every
example below then applies to the names it sets. A line of it the tool cannot
read stops every run until it is fixed, and so does a file that is there and
cannot be opened, rather than falling back to the defaults.

The stages
----------

```
in-progress  →  gh pr create  →  to-staging  →  gh pr merge --rebase  →  closed
                                  (repeat)
```

`in-progress`, `to-staging` and `closed` are `gitflow` stages. Opening and
merging the pull request are `gh` commands, described below in their place:
[the pull request](#the-pull-request) and [shipping](#shipping). Only
`to-staging` repeats: once per round of commits while the ticket is being
reviewed on staging. Everything else happens once per ticket.

`gitflow ABC-123 pr` and `gitflow ABC-123 deployable` were removed, and only
print the `gh` command that replaced them. `resolved` and `resolved sync` are
deprecated — run them only when a failure message names them, which happens when
a staging sync conflicted (see [conflicts.md](conflicts.md)).

Run one step and stop there. What separates the steps happens outside git — a
code review, a round of testing on staging, a push somebody has to make — so
chaining them in one sitting is how a ticket reaches production before anyone has
looked at it. The merge waits until the user says the ticket has been accepted on
staging, and `closed` until the merge has happened.

Rules
-----

1. **Decide on the printed result.** Every run ends with `[INFO] BUILD SUCCESS`
   or `[INFO] BUILD FAILURE`, and exits 0 or 1 to match, so either one answers.
   Read the last lines and the `[ERROR]` lines above them; never report a stage
   as done without seeing `BUILD SUCCESS`.
2. **Never push staging or production.** `to-staging` stops with the commit
   sitting in the local branch, and that manual push is deliberate. Show what is
   queued (`git log --oneline origin/staging..staging`) and let the user push, or
   ask first and quote the exact command. Production is never pushed at all; it
   changes only through the merge.
3. **Merge only on the user's word.** Merging the pull request is what ships the
   ticket to the live server. Run `gh pr merge` only when the user has said, in
   so many words, that the ticket is accepted and should ship - not because the
   PR is approved or staging looks fine. Quote the command and wait for a yes.
   Always `--rebase`; never `--squash`, `--merge`, `--admin` or
   `--delete-branch`.
4. **Ask before `closed`.** It deletes the ticket branch and every
   `ABC-123-track-N` bookmark, local and remote, with no undo. It stops to ask
   only when some of them hold commits production has not got, and with no
   terminal to ask on it deletes nothing and fails - so get the user's answer
   before running it, not from it.
5. **Do not improvise recovery.** A stage that fails prints the commands that
   finish the job; follow those. Never reach for `git cherry-pick --abort`,
   `git cherry-pick --skip`, `git rebase --abort`, `git reset --hard` or
   `git push --force` on your own initiative — each one discards work that
   somebody still needs.
6. **One ticket per run.** There is no batch mode, and the ticket slot takes a
   branch name, never a list. `self` is reserved for the tool itself.

`in-progress`
-------------

```bash
gitflow ABC-123 in-progress
```

Puts you on the ticket branch, creating it from production and pushing it when it
is new. Safe to re-run: that is how you get back on the branch and pick up a
teammate's commits. It does not bring production changes into the branch — for
that run `git pull --rebase origin master` on the ticket branch yourself.

Then commit and push with plain git. Nothing about the day-to-day work goes
through `gitflow`.

The pull request
----------------

```bash
gh pr create --base master --head ABC-123
```

Not a `gitflow` stage. Open it once, as soon as the ticket branch has commits,
so review runs while the ticket is tested on staging; it follows the branch, so
later pushes need no second one. `--base` is the production branch, which
`.gitflow` may name differently. Ask before creating it - it is visible to the
team - and give the user the URL `gh` prints. `gh pr view ABC-123` says whether
one is open already.

`to-staging`
------------

```bash
gitflow ABC-123 to-staging
```

Cherry-picks the ticket commits staging has not seen yet, commits them with a
message naming those commits, and pushes an `ABC-123-track-N` bookmark recording
how far staging has caught up. Leaves you on staging, one commit ahead of
`origin/staging`, and prints the push for the user to run.

Satisfy its three preconditions before calling it, because it commits without a
stop for review and refuses rather than sweep anything in:

* **the ticket branch fully pushed** — `git push` on it first, or the stage stops
  with `Local changes need to be pushed to ABC-123`;
* **no modified tracked files** — commit them on the ticket branch. Untracked
  files never block it. Do not stash on the user's behalf without saying so;
* **no half-finished git operation** — a cherry-pick, rebase, merge, revert or
  `git am` in flight makes it refuse and name what it found. `resolved` refuses
  on the same list. See [conflicts.md](conflicts.md).

Leave `-m` out and let it name the commits it picked (`ABC-123 a1b2c3d 4e5f6a7`)
unless the user wants a subject of their own. `-m` takes every word after it, so
it has to come last.

An empty range is reported and nothing happens, so a second run right after a
successful one is harmless.

To check the picked tree before it is committed, pass a command:
`gitflow ABC-123 to-staging --verify "<command>"`, before any `-m`. It runs from
the top of the clone on staging with the picks applied and not yet committed.
**Exit 3** means the command failed: staging is back where it was, nothing was
committed and no bookmark exists, locally or on origin. There is nothing to
clean up, so do not reset, delete branches or re-pick by hand; report the
command's output and fix the cause on the ticket branch. Exit 1 keeps its usual
meaning (a conflict, a refusal, an error).

Shipping
--------

```bash
gh pr merge ABC-123 --rebase
```

Not a `gitflow` stage, and the one step that reaches the live server: rule 3
applies in full. Before asking the user, check the PR can be merged:

```bash
gh pr view ABC-123 --json state,mergeable,mergeStateStatus,reviewDecision
```

`--rebase` replays the ticket's commits onto production with no merge commit,
and GitHub marks the PR merged. The commits get new SHAs, so the local ticket
branch no longer looks contained in production - `closed` compares by patch and
copes with that. A squash would not: its one commit matches none of the ticket's,
and `closed` would take the whole ticket for unmerged work.

When GitHub refuses because the branch cannot be rebased, the ticket conflicts
with production. Rebasing it is a force push, so it is the user's call - see
[conflicts.md](conflicts.md#the-pull-request-cannot-be-rebased). A refusal for
missing approvals or failing checks is for the user to resolve; never reach for
`--admin`.

`closed`
--------

```bash
gitflow ABC-123 closed
```

Deletes the ticket's branches, local and remote, and leaves you on production.
Ask first (rule 4). A ticket nothing matches is refused - `No branch here or on
origin matches ABC-123 - nothing to delete` - rather than reported as a success. Branches are matched on the ticket as a whole word inside the
branch name, so a prefix narrows the deletion: `gitflow ABC-123-track closed`
removes only the bookmarks and leaves `ABC-123` alone. The production and staging
branches are never deleted, whether they are named in the ticket slot or matched
by it.

A branch with commits that are not on `origin/master` needs a `y` on the terminal,
and there is no terminal on a run of yours:

```
[INFO] Commits not in origin/master: ABC-123 origin/ABC-123
[ERROR] Nothing deleted: that needs a confirmation and there is no terminal to ask on
[INFO] BUILD FAILURE
```

Nothing was deleted. Show the user that list — production has not got those
commits, which is all the check establishes; they may well be on staging or on
another branch — and let them run the command themselves. Do not work around the prompt with
`git push origin --delete` or `git branch -D`.

Where does the ticket stand
---------------------------

When the user names a ticket without naming a stage, work it out before choosing:

```bash
git fetch
git branch -a --list '*ABC-123*'                    # the branch, and its -track-N bookmarks
git log --oneline origin/ABC-123-track-2..ABC-123   # not yet on staging (highest N)
gh pr view ABC-123 --json state,url                 # no PR, OPEN, or MERGED
```

No branch anywhere means the ticket has not started (`in-progress`). Bookmarks
count the rounds already synced: none means staging has never had it. No pull
request means it has not been opened yet. `MERGED` means the ticket has shipped
and only `closed` is left. Do not judge that from `git branch --contains`: the
rebase-merge gives the commits new SHAs, so production never contains the ticket
tip.

When a run fails
----------------

| Message | Do this |
| --- | --- |
| `[ERROR] Update workflows to the latest version` | `gitflow self update`, then re-run the stage. If it reports unpushed local commits in the tool's own clone, tell the user — the check keeps failing until those are pushed or dropped |
| `Add your private key ssh-add [path to pk].` | the user's ssh agent has no key for github.com - checked for every stage, but only on an ssh `origin` there, after git's `insteadOf` rewrites. Ask them to load it (`ssh-add ~/.ssh/id_ed25519`); do not go looking for key files yourself |
| `[ERROR] gitflow must be run inside a project clone` | `cd` into the project first; the tool reads the repository root and `origin` from the working directory |
| `[ERROR] Local changes need to be pushed to ABC-123` | `git push` on the ticket branch, then re-run |
| `[ERROR] Branch ABC-123 does not exist locally` / `[ERROR] Branch origin/ABC-123 does not exist - push it first` | the ticket branch, or origin's copy of it, is missing - check the name against `git branch -a` before anything else. `in-progress` starts a ticket that has no branch; a branch that never left the machine needs `git push` |
| `[ERROR] Commit or stash your local changes before to-staging` | commit the modified tracked files on the ticket branch, then re-run |
| `[ERROR] Configured branch origin/staging does not exist` | stop and ask. The deployed branches must already exist on `origin`; the tool never creates them |
| `[ERROR]` lines quoting git on a checkout (`… would be overwritten by checkout`, `already used by worktree`) | the stage could not check out the branch it works on, and nothing after that checkout ran - earlier steps of the stage may already have done their work. The reason is git's own: uncommitted work in the way, or another worktree holding the branch. Show it and let the user decide - do not stash, reset or remove files to clear it |
| `[ERROR] pr was removed` / `[ERROR] deployable was removed` | the step is a `gh` command now: [the pull request](#the-pull-request), [shipping](#shipping) |
| `Available commands are: …` | the stage name was wrong |
| `[ERROR] A cherry-pick / rebase / merge / revert / am … is in progress on …` | the stage found a git operation open and changed nothing. Report what it named and follow its printed lines; do not abort anything to clear the way (rule 5) |
| anything naming a cherry-pick, a rebase, a merge, a revert or a conflict | [conflicts.md](conflicts.md) |
| `gh pr merge` refuses: the branch cannot be rebased | [conflicts.md](conflicts.md#the-pull-request-cannot-be-rebased) |

The noisier commands write their output to a log of the run's own,
`gitflow-output.XXXXXX` under `$TMPDIR` (`/tmp` when that is unset). One file per
run; the newest is the run you just watched.
