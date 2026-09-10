Command reference
=================

```
gitflow <TICKET> <STAGE> [OPTION] [-m "message"]
```

`TICKET` is the ticket ID, which is also the branch name. A leading `origin/` is
stripped, so tab-completing a remote branch works. The name has to match
`^[A-Za-z0-9][-A-Za-z0-9._/]*$`.

`STAGE` is one of `in-progress`, `pr`, `to-staging`, `deployable`, `closed` —
which is also the order a ticket runs them in — plus the deprecated `resolved`.
`OPTION` is only ever `sync`, for `resolved`. `-m` applies to `to-staging` and to
`resolved sync`.

`self` is a reserved word in the ticket slot: it addresses the tool itself, so it
can never be a ticket. See [tool commands](#tool-commands).

Every run does the same preflight before the stage: fetches this tool's own clone
and stops if it is behind its remote, requires the current directory to be inside
a git clone, reads that repo's `origin` URL, checks `ssh -T git@github.com` for a
loaded key when that URL is an ssh one on github.com and the stage is not `pr` -
stopping both when ssh refuses and when ssh cannot be run at all -
loads `.gitflow` if present, then runs `git fetch` and `git remote prune origin`
in the project and stops if that fetch fails, rather than work from refs it could
not update. It finishes with `BUILD SUCCESS` or `BUILD FAILURE`, and exits 0 or 1
to match, so a run can be read by a script, a CI step or an `&&` chain. Output of
the noisier commands is written to a log of the run's own under `$TMPDIR`, or
under `/tmp` when that is unset.

Every stage works on a branch it checks out first, and acts on whatever is
checked out afterwards, so a checkout that fails ends the run then and there with
git's own reason under `[ERROR]`. The usual causes are a worktree holding changes
the switch would overwrite, a branch another `git worktree` has, and a branch name
two remotes carry while you have no local copy.

Examples below use `ABC-123` as the ticket and the default branch names.

`in-progress`
-------------

Puts you on the ticket branch, creating it from production if it is new.

```bash
gitflow ABC-123 in-progress
```

What it runs, depending on where the branch already exists:

```bash
git checkout ABC-123                          # exists locally
git checkout -b ABC-123 origin/ABC-123        # exists on origin only
                                              # exists nowhere:
git checkout -b ABC-123 origin/master
git push origin ABC-123
git branch -u origin/ABC-123

git pull --rebase origin ABC-123              # in all three cases, last
```

Leaves you on `ABC-123`, level with its remote. Safe to re-run: that is how you
return to the branch and pick up a teammate's commits. It does not bring
production changes into the branch — do that with `git pull --rebase origin master`
when you need it.

`pr`
----

Prints the GitHub compare URL for a pull request from the ticket branch into
production. Runs no git commands.

```bash
$ gitflow ABC-123 pr
[INFO] https://github.com/lecturio/web-apps/compare/master...ABC-123?expand=1
```

The URL is built from the repo's `origin`, which may be `git@github.com:…`,
`ssh://git@github.com/…` or `https://github.com/…`; anything else is an error.
Slashes in branch names are percent-encoded, so `release/1.2` becomes
`release%2F1.2`.

The pull request is for code review. Open it once, as soon as the branch has
commits on it, and leave it open while the ticket goes round `to-staging`: it
follows the branch, so every later push shows up in it. Merging it on GitHub is
not part of this workflow — `deployable` plus your push is what updates
production.

`to-staging`
------------

Cherry-picks the commits added since the last sync onto staging, commits them, and
records how far staging has caught up: one command for what the deprecated
`resolved` and `resolved sync` do in two.

```bash
gitflow ABC-123 to-staging
git push origin staging
```

Requires the ticket branch to be fully pushed, a worktree with no modified tracked
files, and both `origin/master` and `origin/staging` to exist.

```bash
git cherry-pick --quit                        # only to clear a finished cherry-pick
git checkout master  && git pull --rebase origin master
git checkout ABC-123 && git pull --rebase origin ABC-123
git checkout staging && git pull --rebase origin staging
git cherry-pick -Xignore-all-space -n <range>
git commit -F <generated message>
git checkout ABC-123
git branch --track ABC-123-track-N            # N = previous highest + 1
git checkout ABC-123-track-N
git push origin ABC-123-track-N
git checkout staging && git pull --rebase origin staging
```

`<range>` is the same one [`resolved`](deprecated.md#resolved) uses: everything
since the highest `origin/ABC-123-track-N`, or `origin/master..ABC-123` on the
first sync. An empty range is reported and nothing else happens — no commit, no
bookmark.

The message names the commits that went in, since nobody writes these by hand:

```
ABC-123 a1b2c3d 4e5f6a7 8b9c0d1
```

With `-m` your text becomes the subject and the commits move into the body, each
with its own subject:

```
ABC-123 checkout rewrite

a1b2c3d ABC-123 add the endpoint
4e5f6a7 ABC-123 fix the validation
```

Leaves you on staging, one commit ahead of `origin/staging`. **The push is
yours** — the tool prints the `git push origin staging` reminder but does not push.

Because it commits without a stop for review, it refuses to start while the
worktree has modified tracked files, rather than folding them into the staging
commit. Untracked files are fine. It also refuses while any git operation is
still open, and says which one it found — `resolved` and `deployable` refuse on
the same list, through the same code, with the advice matched to what each of
them can offer next:

* unresolved conflicts, from a cherry-pick, a rebase, a merge, a revert or an
  interrupted `git am` (which keeps its state where a rebase does, and is told
  apart by the `rebase-apply/applying` marker so the advice names `git am`). Only
  for a cherry-pick does it point at `resolved sync`, because that is the only one
  those commands can finish; for the others it tells you to finish or abandon the
  operation with git itself. A revert of several commits runs through the same
  sequencer a cherry-pick does, and `REVERT_HEAD` is gone once its conflict is
  committed, so the queue's own verb is what decides which operation you are
  told about.
* a resolution that is staged but not committed. `git cherry-pick --continue`
  refuses in that state, so the commit has to come first, and `resolved sync -m`
  does both that and the bookmark.
* a cherry-pick paused with its conflicts already resolved (`git status`:
  "all conflicts fixed: run git cherry-pick --continue"). Its own picks never
  reach that state, so this is work by hand and it is left alone.
* a cherry-pick with commits still queued behind a conflict you resolved by hand,
  since only `git cherry-pick --continue` can apply those.
* a cherry-pick that stopped on a merge commit, which leaves part of a range
  staged; committing that would put half a range on staging. It is told apart
  from a staged resolution by whether the commit the queue stopped on is itself a
  merge.

The operation is named before the worktree is called dirty, because a resolution
that is staged looks exactly like local changes of your own, and "commit or stash"
is the one thing not to do in the middle of a rebase.

A cherry-pick it finds this way need not be its own. `resolved sync` is offered
only when the pick is on staging and applying one of the commits in this ticket's
own sync range; otherwise the pick is somebody else's, and following
ticket-specific advice would commit their work and bookmark your ticket as synced
when none of its commits went in. Being reachable from the ticket branch is not
enough — every commit of production is — so it is the range that decides. For a
pick that is not this ticket's, the stage names the commit being applied and hands
it back to git, with the next step matched to where the pick stands: `--continue`
on a clean tree, a commit first when a resolution is staged.

State left behind by a cherry-pick that is already finished is the one thing it
clears, with `git cherry-pick --quit`, which keeps your index; `--abort`, which
rewinds, is never run for you.

Anything other than `-m` after the stage name is an error, `sync` included: that
option belongs to `resolved`. `-m message` takes every word after it, so an
attached `-mmessage` or `--message=message` must be the last argument — anything
following one of those is rejected rather than ignored. The message is trimmed,
and one that is empty or nothing but spaces is an error: git strips a blank
subject line, so it would silently commit under the first line of the generated
body instead.

On conflict nothing is committed and no tracking branch is created. The conflicted
cherry-pick is left in place, and the message names the commit it stopped on along
with anything still queued behind it:

```
[ERROR] Cherry-pick onto staging conflicts - nothing was committed
[INFO] Stopped on 2654521 ABC-123 conflicting edit
[INFO] Fix the conflicted files and "git add" them, then:
[INFO]   git commit && git cherry-pick --continue     # 1 more commit(s); if one conflicts, fix it, git add, and repeat
[INFO]   git status                                   # -n leaves the ones that applied cleanly staged
[INFO]   gitflow ABC-123 resolved sync -m "message"   # commits what is staged, then bookmarks
[INFO]   gitflow ABC-123 resolved sync                # instead of the line above when nothing is left staged
[INFO] Or start over with: git cherry-pick --abort
```

The `git status` step is not decoration. `--continue` keeps the `-n` the range
started with, so commits after the conflicted one apply **staged and
uncommitted**; `resolved sync` with no `-m` would then bookmark over work that was
never committed. Passing `-m` commits it first. When the conflict was on the last
commit of the range there is nothing queued behind it, and the message says so by
offering only the `resolved sync -m` line.

Re-running it while those conflicts are unresolved refuses too, so a half-finished
resolution is never thrown away.

A cherry-pick can also fail without leaving a conflict, and that is reported
differently, because there is nothing to resolve:

```
[ERROR] Cherry-pick onto staging failed - git's reason is above
[INFO] Nothing was committed and no bookmark was made
[INFO] origin/master..ABC-123 holds a merge commit, which cherry-pick cannot apply
[INFO] Throw away what did apply with: git cherry-pick --abort
```

A merge commit in the range is the usual cause: `git cherry-pick` refuses to apply
one without being told which side to keep. The commits before it are staged, and
committing that would put half a range on staging under a bookmark claiming all of
it, so the stage points at `--abort` instead of at `resolved sync`. Rebase the
ticket branch instead of merging into it, and the range stays pickable.

`deployable`
------------

Folds the ticket into production. One-time operation, at the end of the cycle.

```bash
gitflow ABC-123 deployable
git log --oneline -5
git push origin master
```

```bash
git checkout master  && git pull --rebase origin master
git checkout ABC-123 && git pull --rebase origin ABC-123   # skipped when the branch has unpushed commits
git checkout ABC-123 && git rebase -Xignore-all-space master
git checkout master  && git rebase -Xignore-all-space ABC-123
```

Leaves you on production, ahead of `origin/master` by the ticket's commits.
**Pushing production is yours**, after reviewing the log.

Conflicts almost always land in the first rebase (ticket onto production); the
second one is usually a fast-forward. `git status` tells you which of the two you
are in. Fix the files, `git add` / `git rm`, `git rebase --continue`, then run
`gitflow ABC-123 deployable` again.

Re-running is not a way to start over. Neither of its rebases can carry a paused
operation forward, so it refuses while one is open — a rebase, a merge, a revert,
a `git am` or a cherry-pick, whoever started it — names it and the branch it is
on, prints git's `--continue` and `--abort` for it, and ends `BUILD FAILURE`
having changed nothing:

```
[ERROR] A rebase with unresolved conflicts is in progress on a detached HEAD
[INFO] Finish it, or abandon it with git rebase --abort, then run deployable again
```

Before 0.0.4 it began with `git rebase --abort`, quiet and unconditional, so a
rebase anybody was half way through was rewound before the stage had looked at
anything — its own, or one you had started for a reason of your own — and the
run went on to report `BUILD SUCCESS`.

`closed`
--------

Deletes the ticket's branches, local and remote.

```bash
gitflow ABC-123 closed
```

```bash
git checkout master
git push origin --delete ABC-123 ABC-123-track-1 …   # all matching remote branches
git branch -D ABC-123 ABC-123-track-1 …              # all matching local branches
```

The checkout comes first for a reason: git will not delete the branch you are
standing on, and the remote copy goes first, so a ticket branch you cannot leave
would be deleted on origin and kept locally. A checkout that fails ends the run
before anything is deleted.

Branches are matched on the ticket as a whole word inside the branch name, so
passing a prefix narrows the deletion: `gitflow ABC-123-track closed` removes the
tracking branches and leaves `ABC-123` in place. That is the first half of the
[staging re-sync](troubleshooting.md#staging-was-recreated). Only `origin` is
searched for the remote branches, so a second remote keeps its copies.

The deployed branches are never deleted. `gitflow staging closed` and
`gitflow master closed` are refused, and a ticket that happens to match one of
them — `release` against `WF_PROD_BRANCH=release/1.2` — takes every other branch
it matched and leaves those two.

**Everything else it deletes, it deletes for good.** The one thing it stops for is
a branch holding commits `origin/master` has not got, which is what an unpushed
`deployable` or work that never landed looks like:

```
[INFO] Commits not in origin/master: ABC-123 origin/ABC-123
[INFO] Delete anyway? [y/N] y
```

Only `y` or `Y` goes ahead; anything else deletes nothing and reports
`BUILD FAILURE`. Commits are weighed by patch, so the rebase in `deployable` and
the cherry-picks in `to-staging` do not make a branch look unmerged for having
different SHAs than production. Merge commits are counted whole, since the patch
comparison walks past them and a merge can carry a resolution that is in neither
of its parents, and a comparison that cannot be made at all counts as unmerged. When there is no terminal to ask on — a script, a pipe, an agent — the
run stops with the same list and deletes nothing, and you run it again by hand.

`resolved`, `resolved sync`
---------------------------

Deprecated, and moved to [docs/deprecated.md](deprecated.md). They split
`to-staging` into a cherry-pick that stops for review and a commit-and-bookmark
step. Both still run, and the conflict advice `to-staging` prints still names
`resolved sync`, which is what finishes a conflicted sync.

Tool commands
-------------

`self` in the ticket slot means "the tool itself" rather than a ticket, and its
only verb is `update`:

```bash
gitflow self update
```

It runs `git pull --rebase` in the tool's own clone, following whatever upstream
that clone's current branch tracks - the same ref the update check compares
against. Being already current is a no-op that succeeds. It works from any
directory, needs no project clone, and is the one command the update check does
not gate, since it exists to clear that check.

It also reports unpushed local commits, because the check fires on any divergence
from the upstream and not only on being behind. Without that line an update looks
successful while the next command still refuses to run:

```
[INFO] 1 local commit(s) not on origin/master - push or drop them or the update check keeps failing
```

The message names the branch's actual upstream, which need not be on `origin`.

A modified worktree stops the update with git's own message; nothing is changed.

Anything else after `self` - an unknown word, a stage name, or nothing at all -
gets a single message and exit 1:

```
[ERROR] "self" is a reserved word and can only be used as: gitflow self update
```

That covers `gitflow self in-progress` too, so no unreachable branch named `self`
can be created through the tool.

Variables
---------

| Variable | Default | Set in | Meaning |
| --- | --- | --- | --- |
| `WF_PROD_BRANCH` | `master` | project `.gitflow`, or environment | branch deployed to the live server |
| `WF_STAGING_BRANCH` | `staging` | project `.gitflow`, or environment | branch deployed to the staging server |

`.gitflow` lives at the project's repository root and is meant to be committed, so
that everyone on the project uses the same branch names. It takes `KEY=value`
lines; blank lines and `#` comments are ignored, and unknown keys are reported and
skipped. Values in the file override the environment.
