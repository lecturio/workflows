Deprecated stages
=================

`resolved` and `resolved sync` are deprecated. They still run, and nothing about
them has been removed from the tool, but they are no longer part of the flow a
ticket is meant to follow:

```
in-progress  →  pr  →  to-staging  →  deployable  →  closed
```

Use [`to-staging`](commands.md#to-staging) instead. It does what `resolved` and
`resolved sync` do together — cherry-pick the new commits onto staging, commit
them, record the sync — in one command, and it writes the commit message for you.

The one place they are still needed
-----------------------------------

`to-staging` refuses to commit over a cherry-pick that conflicted, and the advice
it prints in that case names `resolved sync`, because committing what is staged
and then bookmarking the round is exactly what finishes a conflicted sync:

```bash
gitflow ABC-123 resolved sync -m "ABC-123 add the thing"
git push origin staging
```

So keep `resolved sync` for finishing a conflict, and follow whatever the error
message tells you — it accounts for commits still queued behind the conflict. The
full procedure is in [conflicts](troubleshooting.md#conflicts).

`resolved` itself, the cherry-pick half, has no such role. Reach for it only if
you want to see a sync staged before it is committed, and know that re-running it
aborts an in-flight cherry-pick and throws away uncommitted work on staging.

Reference
---------

What follows is the reference these two stages had in
[docs/commands.md](commands.md), kept here unchanged, plus the one recovery note
from [troubleshooting](troubleshooting.md) that applies to them alone. Examples
use `ABC-123` as the ticket and the default branch names.

`resolved`
----------

Cherry-picks the commits added since the last sync onto staging, and stops before
the commit so you can review them. [`to-staging`](commands.md#to-staging) is the
same work in one step; reach for `resolved` when you want to see the cherry-pick
before it is committed, or to finish one that conflicted.

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
git commit && git cherry-pick --continue      # for each further conflict: fix, git add, repeat
git status                                    # commits that applied cleanly are staged
gitflow ABC-123 resolved sync -m "…"          # commits them, then bookmarks
gitflow ABC-123 resolved sync                 # use this when nothing is left staged
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

I ran `resolved sync` before `resolved`
---------------------------------------

The sync recorded a bookmark that was never actually cherry-picked. Delete the
newest tracking branch, locally and on the remote, then run `resolved` again:

```bash
git push origin :ABC-123-track-3     # 3 = highest existing number
git branch -D ABC-123-track-3
gitflow ABC-123 resolved
```
