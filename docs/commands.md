Command reference
=================

```
gitflow <TICKET> <STAGE> [OPTION] [-m "message"]
```

`TICKET` is the ticket ID, which is also the branch name. A leading `origin/` is
stripped, so tab-completing a remote branch works. The name has to match
`^[A-Za-z0-9][-A-Za-z0-9._/]*$`.

`STAGE` is one of `in-progress`, `to-staging`, `resolved`, `deployable`, `closed`,
`pr`. `OPTION` is only ever `sync`, for `resolved`. `-m` applies to `to-staging`
and to `resolved sync`.

`self` is a reserved word in the ticket slot: it addresses the tool itself, so it
can never be a ticket. See [tool commands](#tool-commands).

Every run does the same preflight before the stage: fetches this tool's own clone
and stops if it is behind its remote, checks `ssh -T git@github.com`, requires the
current directory to be inside a git clone, reads that repo's `origin` URL, loads
`.gitflow` if present, then runs `git fetch` and `git remote prune origin` in the
project. It finishes with `BUILD SUCCESS` or `BUILD FAILURE`. Output of the
noisier commands is written to `output.log` in the tool's own directory.

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

`to-staging`
------------

Cherry-picks the commits added since the last sync onto staging, commits them, and
records how far staging has caught up: one command for what `resolved` and
`resolved sync` do in two.

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

`<range>` is the same one [`resolved`](#resolved) uses: everything since the
highest `origin/ABC-123-track-N`, or `origin/master..ABC-123` on the first sync.
An empty range is reported and nothing else happens — no commit, no bookmark.

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
worktree has modified tracked files, or while a cherry-pick still holds unresolved
conflicts, rather than folding either into the staging commit. Untracked files are
fine. It also refuses while a cherry-pick still has commits queued behind a
conflict you resolved by hand, since only `git cherry-pick --continue` can apply
those. State left behind by a cherry-pick that is already finished is cleared with
`git cherry-pick --quit`, which keeps your index; `--abort`, which rewinds, is
never run for you.

Anything other than `-m` after the stage name is an error, `sync` included: that
option belongs to `resolved`.

On conflict nothing is committed and no tracking branch is created. The conflicted
cherry-pick is left in place, and the message names the commit it stopped on along
with anything still queued behind it:

```
[ERROR] Cherry-pick onto staging conflicts - nothing was committed
[INFO] Stopped on 2654521 ABC-123 conflicting edit
[INFO] Fix the conflicted files and "git add" them, then:
[INFO]   git commit && git cherry-pick --continue     # 1 more commit(s) to apply, repeat per conflict
[INFO]   git status                                   # -n leaves the ones that applied cleanly staged
[INFO]   gitflow ABC-123 resolved sync -m "message"   # commits what is staged, then bookmarks
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

`resolved`
----------

Cherry-picks the commits added since the last sync onto staging, and stops before
the commit so you can review them. [`to-staging`](#to-staging) is the same work in
one step; reach for `resolved` when you want to see the cherry-pick before it is
committed, or to finish one that conflicted.

```bash
gitflow ABC-123 resolved
```

Requires the ticket branch to be fully pushed, and both `origin/master` and
`origin/staging` to exist.

```bash
git cherry-pick --abort                       # clears an unfinished cherry-pick
git checkout master  && git pull --rebase origin master
git checkout ABC-123 && git pull --rebase origin ABC-123
git checkout staging && git pull --rebase origin staging
git cherry-pick -Xignore-all-space -n <range>
```

Any of those three branches is created from `origin` first if you don't have it
locally. `<range>` is `origin/ABC-123-track-<highest>..ABC-123`, or
`origin/master..ABC-123` on the first sync — see [tracking
branches](concepts.md#tracking-branches-abc-123-track-n).

Leaves you on staging with the changes **staged but not committed**. Review them
(`git status`, `git diff --cached`), then continue with `resolved sync`.

On conflict: fix the files and `git add` / `git rm` them. If the range held
nothing after the conflicting commit, `resolved sync -m "…"` finishes the job. If
commits were still queued behind it, `git cherry-pick --continue` refuses while
the resolved changes sit staged and uncommitted, which is exactly what `-n` leaves
you with, so commit first:

```bash
git commit && git cherry-pick --continue      # repeat for each further conflict
git status                                    # commits that applied cleanly are staged
gitflow ABC-123 resolved sync -m "…"          # commits them, then bookmarks
```

`--continue` keeps the `-n`, so the commits after the conflicted one land staged
and uncommitted. `resolved sync` without a message only bookmarks, which would
leave that work sitting uncommitted on staging behind a bookmark that claims it is
already there.

To start over, re-run `gitflow ABC-123 resolved` — it aborts the in-flight
cherry-pick first, which also means **re-running throws away uncommitted
cherry-pick work on staging**.

`resolved sync`
---------------

Commits the staged changes on staging and records how far staging has caught up.

```bash
gitflow ABC-123 resolved sync -m "ABC-123 add the thing"
git push origin staging
```

```bash
git commit -am "ABC-123 add the thing"        # only when -m is given
git checkout ABC-123
git branch --track ABC-123-track-N            # N = previous highest + 1
git checkout ABC-123-track-N
git push origin ABC-123-track-N
git checkout staging && git pull --rebase origin staging
```

Leaves you on staging, one commit ahead of `origin/staging`. **The push is
yours** — the tool prints `git push staging` as a reminder but does not push.

`-m` is optional. Commit the staged changes yourself (IDE, or
`git commit -am "…"`) and then run `gitflow ABC-123 resolved sync` with no
message.

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

The pull request is for code review. Merging it on GitHub is not part of this
workflow — `deployable` plus your push is what updates production.

`deployable`
------------

Folds the ticket into production. One-time operation, at the end of the cycle.

```bash
gitflow ABC-123 deployable
git log --oneline -5
git push origin master
```

```bash
git rebase --abort                            # clears an unfinished rebase
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
`gitflow ABC-123 deployable` again. Re-running is also how you start over, since
it aborts first.

`closed`
--------

Deletes the ticket's branches, local and remote. **It deletes immediately, with no
confirmation and no undo.**

```bash
gitflow ABC-123 closed
```

```bash
git checkout master
git push origin :ABC-123 :ABC-123-track-1 …   # all matching remote branches
git branch -D ABC-123 ABC-123-track-1 …       # all matching local branches
```

Branches are matched with `git branch | grep -w <TICKET>`, so passing a prefix
narrows the deletion: `gitflow ABC-123-track closed` removes the tracking branches
and leaves `ABC-123` in place. That is the first half of the
[staging re-sync](troubleshooting.md#staging-was-recreated).

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
