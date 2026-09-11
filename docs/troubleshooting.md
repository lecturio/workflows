Troubleshooting
===============

Error messages
--------------

| Message | Cause | Fix |
| --- | --- | --- |
| `[ERROR] Could not add tab completion to ~/.profile` | the completion loader is not in that file and the run could not append it - the file is root-owned, read-only, or the home directory is. bash's own reason follows on the next `[ERROR]` line. Every run stops here until it is settled, because nothing was written for the next run's check to find | make the file writable, or paste the three lines the run prints into it yourself |
| `[ERROR] Update workflows to the latest version` | the tool's own clone differs from its remote: behind it, or carrying unpushed local commits of your own | `gitflow self update`, then push or move aside any local commits it reports |
| `Add your private key ssh-add [path to pk].`, under `[ERROR]` lines quoting ssh | the key check before the stage failed. It runs for every stage but `pr`, and only when `origin` is an ssh URL on github.com; it never prompts, so a host key you have not seen before fails it too | load your key, e.g. `ssh-add ~/.ssh/id_ed25519`, and check you can reach github.com |
| `[ERROR] ssh exited 127, so whether github.com takes your key is unknown` | the key check ran `ssh` and got a status that is not ssh reporting on the key: 127 is no `ssh` on the machine, and other statuses come from a broken `ssh` invocation. 0 and 1 pass, 255 is a refusal and gets the key message above | install or repair `ssh`, then re-run; check `ssh -o BatchMode=yes -T git@github.com` by hand |
| `[ERROR] gitflow must be run inside a project clone` | the current directory is not inside a git repository | `cd` into the project you want to act on |
| `[ERROR] Could not read origin URL from the current repository` | the project has no `origin` remote | `git remote add origin …` |
| `[ERROR] fatal: Could not read from remote repository.`, or another `git fetch` error | the stage's own `git fetch` failed - offline, or origin unreachable - and it stops rather than work from refs it could not update | get back on the network, or fix the remote, then re-run |
| `[ERROR] Could not open a command log in /tmp` | `$TMPDIR`, or `/tmp` when that is unset, is not writable, and the commands that report through `[INFO]` have nowhere to write | make it writable, or point `TMPDIR` at somewhere that is |
| `Provide parameters: gitflow JIRA-001 in-progress` | ticket or stage missing | pass both: `gitflow ABC-123 in-progress` |
| `Available commands are: in-progress to-staging resolved deployable closed pr` | the stage name is not one of those six | note it is `deployable`, not `deployed` |
| `[ERROR] Invalid branch name for WF_TASK: …` | the ticket ID has characters the tool refuses | names must match `^[A-Za-z0-9][-A-Za-z0-9._/]*$` |
| `[ERROR] Configured branch origin/devel does not exist` | `.gitflow` (or the environment) names a branch that isn't on `origin` | fix the name or push the branch |
| `[ERROR] Cannot read /path/to/project/.gitflow: …` | a line of `.gitflow` is not `KEY=value`, a `#` comment or blank. It stops the run: these keys decide which shared branch the work goes to, and skipping the line used to leave `master` and `staging` in use while the file asked for other names | fix the line. Spaces around the `=` are fine and the value may be quoted or bare |
| `[ERROR] Cannot read /path/to/project/.gitflow` (no line after it) | the file is there and could not be opened - permissions, usually. The run used to carry on with `master` and `staging`, with bash's own `Permission denied` on stderr the only sign, and on a project carrying both pairs of names the ticket was cut from the abandoned branch under `BUILD SUCCESS` | `chmod` it readable, or remove it if the project no longer renames its branches |
| `[ERROR] Branch ABC-123 does not exist locally` / `[ERROR] Branch origin/ABC-123 does not exist - push it first` | `to-staging` and `resolved` weigh the ticket branch against origin's copy, and one of the two is not there - usually a typo'd ticket, or a branch that never left this machine | check the name with `git branch -a`; run `in-progress` for a ticket that has not started, or `git push` one that only exists locally |
| `[ERROR] deployable works on the branch ABC-123, and it is not in this repository` | `deployable` rebases the local ticket branch, and there is none - usually a typo'd ticket, or a clone that never had it | check the name with `git branch`, or run `in-progress`, which creates it from origin or from production |
| `[ERROR] No branch here or on origin matches ABC-123 - nothing to delete` | `closed` found no branch with the ticket in its name; it used to report `BUILD SUCCESS` for that | check the name with `git branch -a`; the ticket may already have been closed |
| `[ERROR] Local changes need to be pushed to ABC-123` | `to-staging` and `resolved` need the ticket branch fully pushed | `git push` on the ticket branch, then re-run |
| `[ERROR] Commit or stash your local changes before to-staging` | the worktree has modified tracked files, and `to-staging` commits without stopping for review | commit them or stash them; untracked files never block it |
| `[ERROR] A cherry-pick with unresolved conflicts is in progress on staging` | an earlier sync conflicted and the conflict is still unresolved. `to-staging`, `resolved` and `deployable` all refuse while it is | finish it (see [conflicts](#conflicts)) or drop it with `git cherry-pick --abort` |
| `[ERROR] Cherry-pick onto staging conflicts - nothing was committed` | `to-staging` or `resolved` could not apply the range cleanly. Both stop on it with `BUILD FAILURE`: the pick is left as git left it, but nothing reached staging | resolve it as the message says, or `git cherry-pick --abort` |
| `[ERROR] to-staging takes no option other than -m: gitflow ABC-123 to-staging [-m "message"]` | a word other than the `-m` forms followed the stage | drop it; `sync` belongs to `resolved`, not to this stage, and no other flag is accepted |
| `[ERROR] resolved does not take "snyc": gitflow ABC-123 resolved [sync [-m "message"]]`, or `[ERROR] resolved sync does not take "…"` | a word the stage has no meaning for. `sync` is the only option it takes, and `-m` belongs to `resolved sync` | check the spelling of `sync`; before 0.0.4 a word like this ran nothing and still reported `BUILD SUCCESS` |
| `[ERROR] A cherry-pick on staging still has 1 commit(s) to apply` | a conflict was resolved and committed, but the rest of the range was never applied | `git cherry-pick --continue`, then `gitflow ABC-123 resolved sync -m "…"`; or `git cherry-pick --abort` to give up on the rest |
| `[ERROR] A cherry-pick is paused on staging with its conflicts already resolved` | a cherry-pick you started by hand is waiting for `--continue` | finish it with `git cherry-pick --continue`, or drop it with `git cherry-pick --abort` |
| `[ERROR] A cherry-pick on staging has nothing left to apply and was never cleared` | the last commit of a conflicted sync was committed by hand, so nothing is queued, but git still counts the pick as in progress and refuses the next one | bookmark the round with `gitflow ABC-123 resolved sync` if that has not been done, then `git cherry-pick --quit`, which keeps your index. `to-staging` clears this one itself |
| `[ERROR] A rebase with unresolved conflicts is in progress on …` (or `merge`, `revert`, `An am`) | another git operation is half-finished, and no stage runs over one: `to-staging`, `resolved` and `deployable` each stop and name it | finish it, or `git rebase --abort` / `git merge --abort` / `git revert --abort` / `git am --abort`; then re-run the stage |
| `[ERROR] Cherry-pick onto staging failed - git's reason is above` | the cherry-pick in `to-staging` or `resolved` failed without a conflict, usually a merge commit in the range | read git's message, then `git cherry-pick --abort`; rebase the ticket branch instead of merging into it |
| `[ERROR] Could not bring staging up to date with origin/staging` + `[INFO] Resolve conflicts manually` | a `git pull --rebase` inside a stage hit a conflict | resolve, `git rebase --continue`, then re-run the stage |
| `[ERROR] A cherry-pick on staging stopped on the merge commit …` | an earlier `to-staging` hit a merge commit in the range; what applied before it is staged | `git cherry-pick --abort`; do not commit it, it is half a range. Rebase the ticket instead of merging into it |
| `[ERROR] A cherry-pick on staging has a resolution staged but not committed` | a conflict was fixed and `git add`-ed but never committed | `gitflow ABC-123 resolved sync -m "…"` when nothing is queued behind it, otherwise `git commit` then `git cherry-pick --continue` first |
| `[ERROR] -m needs a message: gitflow ABC-123 to-staging -m "message"` (or `resolved sync`) | `-m` was given with nothing after it, or only spaces | pass a message, or leave `-m` out - `to-staging` then names the commits it picked, and `resolved sync` only bookmarks a round you committed yourself |
| `[INFO] It is applying 4108f0e OTHER-999 one, which is not part of ABC-123` | the cherry-pick in flight belongs to another ticket | finish or abort it with git; `resolved sync` would bookmark the wrong ticket |
| `[INFO] It is applying 4108f0e OTHER-999 one` | `deployable` found a cherry-pick paused, and there is nothing it can do with one whoever it belongs to | finish it or abort it with git, then run `deployable` again |
| `[ERROR] A revert is in progress on staging` | a `git revert` of several commits is half-finished; its queue outlives `REVERT_HEAD` | `git revert --continue`, or `git revert --abort` |
| `[ERROR] remote: rejecting refs/heads/ABC-123-track-N` | the remote refused the bookmark push, e.g. a protected-ref rule | the local bookmark stays behind and the next sync numbers past it, so fix the rule and re-run; delete the stray with `git branch -D ABC-123-track-N` if you want the numbers tidy |
| `[ERROR] WF_REPO must point at github.com (ssh or https)` | `pr` can only build GitHub compare URLs | use a GitHub `origin`, or open the PR by hand |
| `[ERROR] staging is a deployed branch and is never deleted` | the ticket slot of `closed` named production or staging | pass a ticket; those two branches are not deletable through the tool |
| `[ERROR] Nothing deleted: that needs a confirmation and there is no terminal to ask on` | some branch `closed` matched has commits `origin/master` has not got, and the run has no terminal to ask on | check the listed branches, then run `gitflow ABC-123 closed` yourself and answer `y` |
| `[ERROR] Nothing deleted` | the confirmation was answered with anything but `y` or `Y` | nothing was deleted; re-run when you mean it |
| `[ERROR] error: Your local changes … would be overwritten by checkout` / `[ERROR] fatal: 'master' is already used by worktree at …` | a stage could not check out the branch it works on, and stopped rather than act on the branch you are standing on | git's reason is in the message: commit or stash what is in the way, or free the branch from the other worktree, then re-run |

Conflicts
---------

**During `to-staging`** you are in a cherry-pick on the staging branch. Check
`git status` and fix the files, then `git add` or `git rm` them. What finishes the
job depends on whether the range had commits after the one that conflicted, which
`to-staging` tells you. This is the one case that still uses `resolved sync`,
otherwise [deprecated](deprecated.md):

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

**During the deprecated `resolved`** you are in the same cherry-pick, and the
stage prints the same lines for it and ends `BUILD FAILURE` too. Stopping there
is what `resolved` is for, but nothing has reached staging until one of the two
forms above is run, so the stage does not report success over it.

**During `deployable`** you are in a rebase. `git status` names the branch being
rebased, which tells you whether you are in the first rebase (ticket onto
production, where conflicts nearly always are) or the second. Fix, `git add` /
`git rm`, `git rebase --continue`, then run `gitflow ABC-123 deployable` again.

No stage clears an operation it did not start. `to-staging`, `resolved` and
`deployable` all refuse while a cherry-pick, a rebase, a merge, a revert or a
`git am` is open: each names the operation and the branch it is on, prints how to
finish it and how to abandon it, and ends with `BUILD FAILURE` having changed
nothing. Re-running a stage is therefore never a way to start over. Before
0.0.4 `resolved` began with `git cherry-pick --abort` and `deployable` with
`git rebase --abort`, both quiet and both before anything had been looked at, so
re-running either of them was how a resolution made by hand disappeared without
a word. Abandoning one is yours to ask for, and yours to type.

The ticket branch looks diverged during a sync
----------------------------------------------

When the ticket branch is up to date on the remote but `to-staging` reports
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
gitflow ABC-123 to-staging
```

or rebuild the local branch from the remote:

```bash
git checkout master           # or your production branch
git branch -D ABC-123
gitflow ABC-123 in-progress
gitflow ABC-123 to-staging
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

The first command leaves `ABC-123` itself alone, because it only matches branch
names containing `ABC-123-track`. It asks before deleting, since the ticket has
not reached production and the bookmarks read as unmerged; the commits are all on
`ABC-123`, which the command does not touch, so answer `y`.

Shell completion
----------------

The first `gitflow` run appends a loader for `gitflow-completion.sh` to
`~/.profile`, or to `~/.bashrc` on Linux, and says so. A run that cannot write
that file stops there with `BUILD FAILURE` and prints the lines to add by hand:
it has nothing to show for the append, and saying the loader was added would be
untrue on that run and on every run after it. Nothing is loaded into the
shell you typed in — a run cannot change the environment of the shell that
started it — so reload that file with `. ~/.bashrc` or `. ~/.profile`, or open a
new shell, and then:

```bash
gitflow ABC-1[tab]      # completes local branches
gitflow origin/[tab]    # completes remote branches
gitflow ABC-123 [tab]   # completes stage names
```

The ticket slot offers branches and nothing else. Production and staging are left
out of it, since they are exactly the names `closed` refuses, and a project that
renames them in `.gitflow` has its own two names left out instead. Before 0.0.4
the slot was filled from raw `git branch` output, so the `* ` marking the branch
you are on glob-expanded into the names of the files in the repository root, and
in detached HEAD the four words of `(HEAD detached at 1a2b3c4)` were offered as
four tickets.

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

A run only checks whether the startup file mentions the path, so a loader written
by a version before those paths were quoted — one naming a clone directory with a
space in its name, which errors on every login shell — is left as it stands.
Quote it by hand, or delete the block and let the next run write it again.

Where the output went
---------------------

The last output of the commands that report through `[INFO]` is kept in a log of
the run's own, `gitflow-output.XXXXXX` under `$TMPDIR` — under `/tmp` when
`TMPDIR` is unset. Each run writes only its own file, so two runs side by side
never overwrite each other's messages, and the newest one is the run you just
watched:

```bash
ls -t "${TMPDIR:-/tmp}"/gitflow-output.* | head -1
```

Versions before 0.0.4 kept it as `output.log` in the tool's own directory, which
failed outright wherever that directory was not writable. A leftover `output.log`
there is still ignored by git and can be deleted.

There is no dry-run mode. To see what a stage runs without running it, read
[the command reference](commands.md), which lists the git commands for each.
