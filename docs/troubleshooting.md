Troubleshooting
===============

Error messages
--------------

| Message | Cause | Fix |
| --- | --- | --- |
| `[ERROR] Update workflows to the latest version` | the tool's own clone differs from its remote: behind it, or carrying unpushed local commits of your own | `gitflow self update`, then push or move aside any local commits it reports |
| `Add your private key ssh-add [path to pk].` | `ssh -T git@github.com` failed | load your key, e.g. `ssh-add ~/.ssh/id_ed25519`, and check you can reach github.com |
| `[ERROR] gitflow must be run inside a project clone` | the current directory is not inside a git repository | `cd` into the project you want to act on |
| `[ERROR] Could not read origin URL from the current repository` | the project has no `origin` remote | `git remote add origin …` |
| `Provide parameters: gitflow JIRA-001 in-progress` | ticket or stage missing | pass both: `gitflow ABC-123 in-progress` |
| `Available commands are: in-progress to-staging resolved deployable closed pr` | the stage name is not one of those six | note it is `deployable`, not `deployed` |
| `[ERROR] Invalid branch name for WF_TASK: …` | the ticket ID has characters the tool refuses | names must match `^[A-Za-z0-9][-A-Za-z0-9._/]*$` |
| `[ERROR] Configured branch origin/devel does not exist` | `.gitflow` (or the environment) names a branch that isn't on `origin` | fix the name or push the branch |
| `[ERROR] Local changes need to be pushed to ABC-123` | `to-staging` and `resolved` need the ticket branch fully pushed | `git push` on the ticket branch, then re-run |
| `[ERROR] Commit or stash your local changes before to-staging` | the worktree has modified tracked files, and `to-staging` commits without stopping for review | commit them, stash them, or use `resolved`, which stops before the commit. Untracked files never block it |
| `[ERROR] A cherry-pick with unresolved conflicts is in progress on staging` | an earlier sync conflicted and the conflict is still unresolved | finish it (see [conflicts](#conflicts)) or drop it with `git cherry-pick --abort` |
| `[ERROR] Cherry-pick onto staging conflicts - nothing was committed` | `to-staging` could not apply the range cleanly | resolve it as the message says, or `git cherry-pick --abort` |
| `[ERROR] to-staging takes no option other than -m: gitflow ABC-123 to-staging [-m "message"]` | a word other than the `-m` forms followed the stage | drop it; `sync` belongs to `resolved`, not to this stage, and no other flag is accepted |
| `[ERROR] A cherry-pick on staging still has 1 commit(s) to apply` | a conflict was resolved and committed, but the rest of the range was never applied | `git cherry-pick --continue`, then `gitflow ABC-123 resolved sync -m "…"`; or `git cherry-pick --abort` to give up on the rest |
| `[ERROR] A cherry-pick is paused on staging with its conflicts already resolved` | a cherry-pick you started by hand is waiting for `--continue` | finish it with `git cherry-pick --continue`, or drop it with `git cherry-pick --abort` |
| `[ERROR] A rebase with unresolved conflicts is in progress on …` (or `merge`, `revert`) | another git operation is half-finished; `to-staging` will not commit over it | finish it, or `git rebase --abort` / `git merge --abort` / `git revert --abort` |
| `[ERROR] Cherry-pick onto staging failed - git's reason is above` | the cherry-pick failed without a conflict, usually a merge commit in the range | read git's message, then `git cherry-pick --abort`; rebase the ticket branch instead of merging into it |
| `[ERROR] Could not bring staging up to date with origin/staging` + `[INFO] Resolve conflicts manually` | a `git pull --rebase` inside a stage hit a conflict | resolve, `git rebase --continue`, then re-run the stage |
| `[ERROR] A cherry-pick on staging stopped on the merge commit …` | an earlier `to-staging` hit a merge commit in the range; what applied before it is staged | `git cherry-pick --abort`; do not commit it, it is half a range. Rebase the ticket instead of merging into it |
| `[ERROR] A cherry-pick on staging has a resolution staged but not committed` | a conflict was fixed and `git add`-ed but never committed | `gitflow ABC-123 resolved sync -m "…"` when nothing is queued behind it, otherwise `git commit` then `git cherry-pick --continue` first |
| `[ERROR] A revert is in progress on staging` | a `git revert` of several commits is half-finished; its queue outlives `REVERT_HEAD` | `git revert --continue`, or `git revert --abort` |
| `[ERROR] remote: rejecting refs/heads/ABC-123-track-N` | the remote refused the bookmark push, e.g. a protected-ref rule | the local bookmark stays behind and the next sync numbers past it, so fix the rule and re-run; delete the stray with `git branch -D ABC-123-track-N` if you want the numbers tidy |
| `[ERROR] WF_REPO must point at github.com (ssh or https)` | `pr` can only build GitHub compare URLs | use a GitHub `origin`, or open the PR by hand |

Conflicts
---------

**During `to-staging` or `resolved`** you are in a cherry-pick on the staging
branch. Check `git status` and fix the files, then `git add` or `git rm` them.
What finishes the job depends on whether the range had commits after the one that
conflicted, which `to-staging` tells you:

```bash
gitflow ABC-123 resolved sync -m "…"          # nothing was queued behind it
git push origin staging
```

```bash
git commit && git cherry-pick --continue      # if a later commit conflicts, fix it, git add, repeat
git status                                    # see what the continue left staged
gitflow ABC-123 resolved sync -m "…"          # commits that, then bookmarks
git push origin staging
```

Use `gitflow ABC-123 resolved sync` **without** `-m` when that `git status` comes
back clean, which is what happens when the last commit of the range was the one
that conflicted and you committed the resolution yourself. With `-m` and nothing
staged, `git commit -am` fails, the stage stops at `BUILD FAILURE`, and no
bookmark is written — leaving staging holding the work while the ticket looks
unsynced.

Neither commit in the second form is optional. The cherry-pick runs with `-n`, so
the resolved changes sit staged and uncommitted, and `git cherry-pick --continue`
refuses to apply the next commit over them with `your local changes would be
overwritten by cherry-pick`. For the same reason the commits that then apply
cleanly are left staged, so the sync needs `-m` to commit them: without it the
bookmark would move as if they were on staging while they are only staged.

Re-running `to-staging` at any point during this refuses and changes nothing, so
it cannot eat a half-finished resolution: while conflicts are unresolved, while a
resolution sits staged, and while commits are still queued behind one. Each of
those gets its own message naming what is left to do. Only when the resolution
was the last commit of the range and has been committed does the sequencer state
git leaves behind get cleared, with `git cherry-pick --quit`, which keeps your
index.

**During `deployable`** you are in a rebase. `git status` names the branch being
rebased, which tells you whether you are in the first rebase (ticket onto
production, where conflicts nearly always are) or the second. Fix, `git add` /
`git rm`, `git rebase --continue`, then run `gitflow ABC-123 deployable` again.

`resolved` and `deployable` can be restarted from scratch by simply re-running
them: `resolved` aborts a pending cherry-pick first, `deployable` a pending
rebase. Both therefore discard whatever you had half-resolved, so use `git log`
and `git status` to see where you stand before you re-run. `to-staging` is the
exception — it refuses instead, and abandoning its cherry-pick is something you
ask for yourself with `git cherry-pick --abort`.

I ran `resolved sync` before `resolved`
---------------------------------------

The sync recorded a bookmark that was never actually cherry-picked. Delete the
newest tracking branch, locally and on the remote, then run `resolved` again:

```bash
git push origin :ABC-123-track-3     # 3 = highest existing number
git branch -D ABC-123-track-3
gitflow ABC-123 resolved
```

The ticket branch looks diverged during `resolved`
--------------------------------------------------

When the ticket branch is up to date on the remote but `resolved` reports
something like:

```
On branch ABC-123
Your branch and 'origin/ABC-123' have diverged,
and have 20 and 1 different commit each, respectively.
```

GitHub usually just needs a moment to catch up. Either:

```bash
git rebase --abort
# wait a little
gitflow ABC-123 resolved
```

or rebuild the local branch from the remote:

```bash
git checkout master           # or your production branch
git branch -D ABC-123
gitflow ABC-123 in-progress
gitflow ABC-123 resolved
```

Staging was recreated
---------------------

When the staging branch is rebuilt from production, every ticket that has not
reached production yet has to be pushed onto the new staging branch again. Drop
the ticket's bookmarks so the next `resolved` picks up the whole ticket, then
resolve as usual:

```bash
gitflow ABC-123-track closed    # deletes ABC-123-track-* only, local and remote
gitflow ABC-123 to-staging
git push origin staging
```

The first command deletes immediately and leaves `ABC-123` itself alone, because
it only matches branch names containing `ABC-123-track`.

Shell completion
----------------

The first `gitflow` run appends a loader for `gitflow-completion.sh` to
`~/.profile`, or to `~/.bashrc` on Linux. Reload it with `. ~/.bashrc` or
`. ~/.profile`, and then:

```bash
gitflow ABC-1[tab]      # completes local branches
gitflow origin/[tab]    # completes remote branches
gitflow ABC-123 [tab]   # completes stage names
```

The script is a bash completion (`complete -F`). zsh reads neither `~/.profile`
nor `complete`, so zsh users have to load it through `bashcompinit`, after
`compinit`, in `~/.zshrc`:

```bash
autoload -U +X bashcompinit && bashcompinit
[ -f /path/to/workflows/gitflow-completion.sh ] && . /path/to/workflows/gitflow-completion.sh
```

Branch-name completion relies on git's own bash completion. Without
[git-completion](https://github.com/git/git/blob/master/contrib/completion/git-completion.bash)
you still get stage names, but not branches.

Where the output went
---------------------

The last output of the commands that report through `[INFO]` is kept in
`output.log` in the tool's directory. It is overwritten on each run and ignored by
git.

There is no dry-run mode. To see what a stage runs without running it, read
[the command reference](commands.md), which lists the git commands for each.
