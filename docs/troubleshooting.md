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
| `Available commands are: in-progress resolved deployable closed pr` | the stage name is not one of those five | note it is `deployable`, not `deployed` |
| `[ERROR] Invalid branch name for WF_TASK: …` | the ticket ID has characters the tool refuses | names must match `^[A-Za-z0-9][-A-Za-z0-9._/]*$` |
| `[ERROR] Configured branch origin/devel does not exist` | `.gitflow` (or the environment) names a branch that isn't on `origin` | fix the name or push the branch |
| `[ERROR] Local changes need to be pushed to ABC-123` | `resolved` needs the ticket branch fully pushed | `git push` on the ticket branch, then re-run |
| `[INFO] Resolve conflicts manually` | a `git pull --rebase` inside `resolved` hit a conflict | resolve, `git rebase --continue`, then re-run the stage |
| `[ERROR] WF_REPO must point at github.com (ssh or https)` | `pr` can only build GitHub compare URLs | use a GitHub `origin`, or open the PR by hand |

Conflicts
---------

**During `resolved`** you are in a cherry-pick on the staging branch. Check
`git status`, fix the files, `git add` or `git rm` them, then
`git cherry-pick --continue`. Finish with
`gitflow ABC-123 resolved sync -m "…"` and `git push origin staging`.

**During `deployable`** you are in a rebase. `git status` names the branch being
rebased, which tells you whether you are in the first rebase (ticket onto
production, where conflicts nearly always are) or the second. Fix, `git add` /
`git rm`, `git rebase --continue`, then run `gitflow ABC-123 deployable` again.

Either stage can be restarted from scratch by simply re-running it: `resolved`
aborts a pending cherry-pick first, `deployable` aborts a pending rebase. Both
therefore discard whatever you had half-resolved, so use `git log` and
`git status` to see where you stand before you re-run.

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
gitflow ABC-123 resolved
gitflow ABC-123 resolved sync -m "ABC-123 add the thing"
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

Looking at what a stage would do
--------------------------------

Copy `sample.config.sh` to `config.sh` in the tool's directory and set
`WF_DEBUG=1`. Each git command is then printed instead of executed:

```
info>>> git checkout -b ABC-123 origin/master <<<
```

This shows intent, not a faithful simulation: stages that read the output of a
command (the highest tracking-branch number, whether a branch exists) see the
printed line instead of a result, so the later steps of a dry run can differ from
a real one. Set it back to `0` when you are done.

The last output of the commands that report through `[INFO]` is kept in
`output.log` in the tool's directory. It is overwritten on each run and ignored by
git.
