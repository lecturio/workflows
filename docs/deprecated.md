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
you want to see a sync staged before it is committed.

Reference
---------

What follows is the reference these two stages had in
[docs/commands.md](commands.md), moved here and kept current with what they
print, plus the one recovery note from
[troubleshooting](troubleshooting.md) that applies to them alone. Examples
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
git checkout master  && git pull --rebase origin master
git checkout ABC-123 && git pull --rebase origin ABC-123
git checkout staging && git pull --rebase origin staging
git cherry-pick -Xignore-all-space -n <range>
```

Any of those three branches is created from `origin` first if you don't have it
locally. `<range>` is `origin/ABC-123-track-<highest>..ABC-123`, or
`origin/master..ABC-123` on the first sync — see [tracking
branches](concepts.md#tracking-branches-abc-123-track-n).

`sync` is the only word it takes in the option slot, and `-m` belongs to that
half — the cherry-pick commits nothing, so it has no message to carry. Anything
else is refused by name:

```
[ERROR] resolved does not take "snyc": gitflow ABC-123 resolved [sync [-m "message"]]
```

Before 0.0.4 an unrecognised word was a silent no-op: `resolved snyc` and
`resolved -m "…"` ran nothing at all and reported `BUILD SUCCESS`, which reads
as a sync that happened.

Leaves you on staging with the changes **staged but not committed**, and prints
what to do with them:

```
[INFO] Review what is staged: git status, git diff --cached
[INFO] Then commit and bookmark it: gitflow ABC-123 resolved sync -m "message"
[INFO] Or commit it yourself first, and bookmark with: gitflow ABC-123 resolved sync
```

`resolved sync` **without** `-m` only bookmarks, which is the third line: it is
the right command once the staged changes have been committed, and the wrong one
while they are still staged. An empty range — staging already level with the
ticket — is reported and nothing else happens.

On conflict the stage reports `BUILD FAILURE` and exits 1. Stopping is what it
is for, and the conflicted pick is left exactly where git left it, but nothing
has reached staging and the round still needs finishing, so the run does not
call that a success. It is the same state `to-staging` reports, with the same
advice:

```
[ERROR] Cherry-pick onto staging conflicts - nothing was committed
[INFO] Stopped on 2654521 ABC-123 conflicting edit
[INFO] Fix the conflicted files and "git add" them, then:
[INFO]   gitflow ABC-123 resolved sync -m "message"   # commits and bookmarks
[INFO] Or start over with: git cherry-pick --abort
```

So: fix the files and `git add` / `git rm` them. If the range held nothing after
the conflicting commit, `resolved sync -m "…"` finishes the job, which is the
form above. If commits were still queued behind it the message says how many, and
`git cherry-pick --continue` refuses while the resolved changes sit staged and
uncommitted, which is exactly what `-n` leaves you with, so commit first:

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

A cherry-pick can also fail without leaving a conflict behind, a merge commit in
the range being the usual cause, and that is reported as itself — there is
nothing to resolve, and what applied before it is half a range, so the way out is
`git cherry-pick --abort` rather than a sync. It reads the same as it does for
[`to-staging`](commands.md#to-staging).

Re-running `gitflow ABC-123 resolved` is not a way to start over. It refuses
while any cherry-pick, rebase, merge, revert or `git am` is open, names the one
it found and the branch it is on, and changes nothing:

```
[ERROR] A cherry-pick with unresolved conflicts is in progress on staging
[INFO] Fix the conflicted files and "git add" them, then:
[INFO]   gitflow ABC-123 resolved sync -m "message"   # commits and bookmarks
[INFO] Or drop it: git cherry-pick --abort
```

A pick that is applying commits of some other ticket, or a rebase or merge of
your own, gets the same refusal with git's own `--continue` and `--abort` named
instead — nothing the stage offers can finish those. Starting over means asking
for it yourself with `git cherry-pick --abort`, and then re-running. Before
0.0.4 the stage ran that abort for you, quietly and before anything had been
looked at, so a conflict resolved by hand and `git add`-ed went back to what
staging held before the pick with nothing printed to say so, and the run still
ended `BUILD SUCCESS`.

Once the last commit of a conflicted round has been committed by hand there is
nothing left to apply, but git still counts the pick as in progress. The stage
says so rather than picking again over it:

```
[ERROR] A cherry-pick on staging has nothing left to apply and was never cleared
[INFO] git counts it as still in progress, and refuses the next cherry-pick while it is there
[INFO] It finished a round of ABC-123: bookmark that with gitflow ABC-123 resolved sync
[INFO] Clear what git left with: git cherry-pick --quit   # keeps your index
```

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
message. What is not optional is the message when `-m` is there: it is trimmed,
and one that is empty or nothing but spaces is an error rather than a silent
fall back to bookmarking, which would leave the staged work uncommitted behind a
bookmark claiming it is on staging.

```
[ERROR] -m needs a message: gitflow ABC-123 resolved sync -m "message"
[INFO] Leave it out to bookmark a round you committed yourself
```

I ran `resolved sync` before `resolved`
---------------------------------------

The sync recorded a bookmark that was never actually cherry-picked. Delete the
newest tracking branch, locally and on the remote, then run `resolved` again:

```bash
git push origin :ABC-123-track-3     # 3 = highest existing number
git branch -D ABC-123-track-3
gitflow ABC-123 resolved
```
