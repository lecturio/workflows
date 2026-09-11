Conflicts and half-finished operations
======================================

Read this when a stage names a cherry-pick, a rebase, a merge, a revert or a
conflict. Two rules first:

* **The message is the instruction.** Both stages print the exact commands that
  finish the job, and those commands account for what git has actually left
  behind. Follow them in order rather than composing your own.
* **A conflict is a judgement call.** Resolving one means knowing which side is
  right. When the two sides are both plausible edits of the same lines, stop and
  put the choice to the user with the conflicted hunk; do not pick a side to get
  the stage green.

Nothing here is fixed by re-running a stage. `to-staging`, `resolved` and
`deployable` all refuse while a resolution is unfinished — which is the point, so
a half-finished resolution is never eaten — and each says what is left to do.

A `to-staging` cherry-pick that conflicted
------------------------------------------

```
[ERROR] Cherry-pick onto staging conflicts - nothing was committed
[INFO] Stopped on 2654521 ABC-123 conflicting edit
```

The deprecated `resolved` prints the same lines for the same state, and ends
`BUILD FAILURE` too — it is meant to stop here, but nothing has reached staging
until the round is finished. Everything below applies to both.

Nothing was committed and no bookmark was made, so the ticket is still recorded
as unsynced. You are in a cherry-pick on the staging branch. Fix the conflicted
files and `git add` (or `git rm`) them, then finish in whichever of the two shapes
the message printed.

**Nothing was queued behind the conflict** — the commit that conflicted was the
last of the range:

```bash
gitflow ABC-123 resolved sync -m "ABC-123 the subject"   # commits and bookmarks
```

**Commits were still queued behind it** — the message says how many:

```bash
git commit && git cherry-pick --continue    # for each further conflict: fix, git add, repeat
git status                                  # see what --continue left staged
gitflow ABC-123 resolved sync -m "ABC-123 the subject"
```

Neither commit in that second form is optional, and the reason matters:

* the cherry-pick runs with `-n`, so a resolution sits staged and uncommitted,
  and `git cherry-pick --continue` refuses to apply the next commit over it
  (`your local changes would be overwritten by cherry-pick`). Hence `git commit`
  first;
* `--continue` keeps that `-n`, so the commits that then apply cleanly are also
  left staged. `resolved sync` **without** `-m` only bookmarks, which would move
  the bookmark as if that work were on staging while it is only staged, and every
  later sync would skip it. Hence `-m`.

Use `gitflow ABC-123 resolved sync` with no `-m` only when `git status` comes back
clean, which is what happens when you committed the last resolution yourself. With
`-m` and nothing staged, `git commit -am` fails, the stage ends `BUILD FAILURE`,
and no bookmark is written — staging then holds the work while the ticket looks
unsynced.

Then the push is the user's: `git push origin staging`.

Giving up on the round is `git cherry-pick --abort`, which throws away everything
resolved so far. Ask before running it.

A stage refuses because something is in flight
----------------------------------------------

`to-staging`, `resolved` and `deployable` all stop on the states below, name the
operation and the branch it is on, and change nothing. Each of these is a
different state, and the response differs. Do not treat them as one "dirty repo"
problem.

The advice differs by stage, because what you can do next does. `resolved` is
the stage for finishing a hand-resolved sync, so for a cherry-pick working
through this ticket's own range it prints the `resolved sync` lines below.
`deployable` can carry nothing forward into its rebases, so it hands every one
of them back to git with `--continue` and `--abort`.

| Message | What it means | The way out |
| --- | --- | --- |
| `A cherry-pick with unresolved conflicts is in progress on staging` | an earlier sync conflicted and was never finished | resolve it as above, or `git cherry-pick --abort` |
| `A cherry-pick on staging has a resolution staged but not committed` | fixed and `git add`-ed, never committed. `--continue` refuses in this state | follow the printed lines: `resolved sync -m` when nothing is queued behind it, otherwise `git commit && git cherry-pick --continue` first |
| `A cherry-pick on staging still has N commit(s) to apply` | a conflict was committed by hand, the rest of the range never applied | `git cherry-pick --continue`, then `resolved sync -m "…"` (or with no `-m` when nothing is left staged) |
| `A cherry-pick is paused on staging with its conflicts already resolved` | somebody's pick by hand, waiting for `--continue`. The stage's own picks never reach this state | leave it to them: `git cherry-pick --continue`, or `--abort`. Tell the user rather than deciding |
| `A cherry-pick on staging stopped on the merge commit …` | see [a merge commit in the range](#a-merge-commit-in-the-range) | `git cherry-pick --abort` — what applied is half a range |
| `A rebase / merge / revert / An am … is in progress on …` | another git operation is half-finished, and no stage can advise on it | follow the two lines it prints: `git <op> --continue` finishes it, `git <op> --abort` drops it, then re-run the stage. With conflicts still open it says to fix the files and `git add` them first, because `--continue` refuses until they are. Never "commit or stash" your way out of a rebase |
| `A cherry-pick on staging has nothing left to apply and was never cleared` | a conflicted round was committed by hand; git counts the pick as in progress and refuses the next one | bookmark the round with `resolved sync` if that has not happened, then `git cherry-pick --quit`, which keeps the index. `to-staging` clears this state itself and never prints this |
| `It is applying 4108f0e OTHER-999 one, which is not part of ABC-123` | the cherry-pick in flight belongs to another ticket | hand it back to git as the message says. **Do not run `resolved sync`** — it would commit their work onto staging and bookmark this ticket as synced when none of its commits went in, and the next sync would skip them for good |

A merge commit in the range
---------------------------

```
[ERROR] Cherry-pick onto staging failed - git's reason is above
[INFO] origin/master..ABC-123 holds a merge commit, which cherry-pick cannot apply
```

This is a failure, not a conflict: there is nothing to resolve. `git cherry-pick`
will not apply a merge commit without being told which side to keep, and the
commits before it are staged — committing that would put half a range on staging
under a bookmark claiming all of it. So `git cherry-pick --abort` is the way out
here, not `resolved sync`.

The fix is upstream of the sync: the ticket branch has a merge in it. Rebase the
ticket onto production (`git pull --rebase origin master` on the branch) instead
of merging into it, and the range becomes pickable again.

A `deployable` rebase that conflicted
-------------------------------------

You are in a rebase, not a cherry-pick. `git status` names the branch being
rebased, which says which of the two you are in — the first (ticket onto
production, where conflicts nearly always are) or the second (usually a
fast-forward).

```bash
# fix the files
git add <files>          # or git rm
git rebase --continue
gitflow ABC-123 deployable
```

Re-running the stage is **not** how you start over. It refuses while the rebase
is open, whether it is its own or one the user started:

```
[ERROR] A rebase with unresolved conflicts is in progress on a detached HEAD
[INFO] Fix the conflicted files and "git add" them, then:
[INFO]   git rebase --continue                        # finishes it
[INFO]   git rebase --abort                           # or drop it
[INFO] Then run deployable again
```

Finishing it is the answer. `git rebase --abort` throws away everything resolved
so far, so it is the user's call, not yours — rule 5.

The ticket branch looks diverged during a sync
----------------------------------------------

```
Your branch and 'origin/ABC-123' have diverged,
and have 20 and 1 different commit each, respectively.
```

With the branch actually pushed, this is usually GitHub needing a moment. Wait,
then re-run the stage. If it persists, rebuild the local branch from the remote:

```bash
git checkout master
git branch -D ABC-123
gitflow ABC-123 in-progress
```

Staging was recreated
---------------------

When staging is rebuilt from production, every ticket that has not reached
production has to be put on it again. Drop the ticket's bookmarks so the next sync
picks up the whole branch:

```bash
gitflow ABC-123-track closed    # deletes ABC-123-track-* only, local and remote
gitflow ABC-123 to-staging
```

The first command deletes immediately, and only matches names containing
`ABC-123-track`, so `ABC-123` itself is left alone. Confirm it with the user all
the same.

The bookmark push was rejected
------------------------------

```
[ERROR] remote: rejecting refs/heads/ABC-123-track-N
```

A protected-ref rule or similar refused the bookmark. The local bookmark stays
behind and the next sync numbers past it, so the fix is on the remote side: report
it to the user. The stray local branch can go with
`git branch -D ABC-123-track-N` if they want the numbers tidy.

Why the bookmarks matter
------------------------

Every sync creates and pushes `ABC-123-track-N`, N counting up from 1, pointing at
the ticket-branch tip that was just synced. It is a bookmark and nothing else: the
next sync cherry-picks `origin/ABC-123-track-N..ABC-123`, or the whole branch when
there is none.

So deleting a bookmark rewinds the sync point, and that is the lever behind the
recoveries above. It also means staging normally gets one commit per sync,
squashing however many ticket commits went into that round, while production later
gets the ticket's individual commits. The two branches are not meant to have
matching history — do not "fix" that.
