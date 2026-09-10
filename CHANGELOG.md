Changelog
=========

Current version: 0.0.4.SNAPSHOT

0.0.4.SNAPSHOT
--------------

* every checkout goes through one function, `emitgit_checkout`, and a checkout
  that fails now ends the run with git's reason under `[ERROR]`. Each stage acts
  on the branch it has just checked out, and the failures were discarded, so the
  commands after them ran against whatever was checked out instead: `closed`
  deleted the ticket from origin and kept it locally, and `deployable` - both of
  its helpers switched branches quiet - rebased the ticket onto itself twice and
  reported `BUILD SUCCESS` with production untouched, which is the run whose
  `git push origin master` ships nothing. A clean worktree is no protection: a
  branch another `git worktree` has checked out, or a name two remotes carry
  while there is no local copy, fails the same way. The stages that already
  stopped on it - `to-staging`, `resolved`, and the bookmark that `to-staging`
  creates - stopped without reporting `BUILD FAILURE`, or without printing
  anything at all, and now do both. The shared checkout says nothing while it
  works, since a switch is plumbing in every stage but one: `in-progress`
  prints the line git wrote for it - `Switched to branch 'ABC-123'`,
  `Already on 'ABC-123'` - because where you end up is that stage's result
* `[ERROR]` prefixes every line of a multi-line message. Git's reason for
  refusing reaches the terminal through `print_err`, and only its first line was
  marked, so the advice underneath read as if the tool had stopped talking
  mid-message
* `closed` deletes through git's argument list instead of a command string that
  `emit` re-parses. Git allows `;`, `$( )` and backticks in a ref name, so a
  branch pushed to origin as `ABC-123;id` ran `id` on the machine of whoever
  closed the ticket. The two deletions also report: a remote that refuses the
  push - a protected-ref rule, a lost race - ends the run with `BUILD FAILURE`
  and the local branches still in place, where before the local deletion went
  ahead regardless and the run claimed success
* `resolved sync` writes your `-m` message to a file and commits it with
  `git commit -F`, the way `to-staging` already did, instead of a command
  string that `emit` re-parses. `-m 'oops $(id)'` ran `id`, and what git kept
  as the message was whatever text the shell had left over
* `closed` reads branch names by component count, `%(refname:lstrip=2)` and
  `lstrip=3`, rather than `%(refname:short)`, which shortens only as far as
  stays unambiguous: with a local branch named `origin/ABC-123` in the
  repository, short reports `heads/origin/ABC-123` and `remotes/origin/ABC-123`,
  neither of which git will delete, so nothing was deleted on either side and
  the run still reported `BUILD SUCCESS`
* `closed` names refs in full where it weighs a branch, and deletes on origin
  through `refs/heads/`. A short name is resolved by precedence - a tag before a
  local branch, a local branch before a remote-tracking one - so a tag called
  `ABC-123`, or a local branch called `origin/ABC-123`, answered for the branch
  being weighed and the ticket was deleted without the confirmation its commits
  had earned; and origin carrying a tag named like the branch made the whole
  delete "dst refspec matches more than one". `git branch -D` keeps bare names,
  which are the only ones it accepts
* the confirmation in `closed` counts what it cannot vouch for. `git cherry`
  walks past merge commits, and a merge can carry a resolution that is in
  neither parent, so a branch whose only unshared work sat in one was deleted
  without asking; merges in the range are now counted on their own. A patch
  comparison that fails at all counts as unmerged, where the error used to be
  discarded and read as nothing to lose
* `closed` no longer deletes branches it was not asked to delete. It read the
  branch list through `git branch`, whose `* ` marker for the checked-out branch
  glob-expanded against the repository root, so a root holding files named
  `master` and `staging` had those local branches deleted; the names are now read
  through `git for-each-ref`, which prints them bare. Production and staging are
  never deleted, in the ticket slot (`gitflow staging closed` removed the shared
  branch from origin and reported `BUILD SUCCESS`) or as something the ticket
  matched. Deleting a branch that holds commits `origin/master` has not got - an
  unpushed `deployable`, work that never landed - now lists them and waits for a
  `y`, and stops with `BUILD FAILURE` when there is no terminal to ask on.
  Remote branches are origin's alone, without `origin/HEAD` and without any
  second remote, whose refs used to abort the whole push; and names are passed to
  `git push origin --delete` as they are, instead of being rewritten with `sed`,
  which had turned local `feat/ABC-123` into two branches that do not exist and
  rewrote any name containing `origin`
* `resolved sync` refuses unless the staging branch is checked out. It commits
  where HEAD stands and bookmarks the ticket as synced either way, so a run from
  a ticket branch put the round there and still recorded the ticket as synced,
  which every later sync then skipped. `to-staging` asserts the same thing
* new `skills/gitflow`, a Claude Code skill to copy into a project's
  `.claude/skills`, so an agent driving the tool knows the order of the stages,
  which pushes are not its to make, that a run reporting `BUILD FAILURE` can
  still exit 0, and how to finish a conflicted sync. Nothing in the tool itself
  changed
* the documented flow is `in-progress`, `pr`, `to-staging`, `deployable`,
  `closed`, with the pull request opened early so review runs while the ticket is
  tested on staging. `resolved` and `resolved sync` are documented as deprecated -
  they still run, and finishing a conflicted sync is what they are still for - and
  their reference moved to `docs/deprecated.md`. Documentation only; no stage
  changed
* removed `WF_DEBUG` and `WF_VERBOSE`, with `sample.config.sh` and the reading of
  the tool's `config.sh`: the dry run `WF_DEBUG=1` promised could not work, since
  the update check read the printed line instead of a result and stopped every
  run, and `WF_VERBOSE` never did anything. A leftover `config.sh` is now ignored
  and can be deleted; branch names come from the project's `.gitflow` or the
  environment
* new stage `to-staging` puts a ticket on staging in one command: it cherry-picks,
  commits and bookmarks, writing a commit message that names the commits it picked
  (`ABC-123 a1b2c3d 4e5f6a7`), and leaves the push to you
* `to-staging` commits nothing when the cherry-pick conflicts, and refuses to
  start on a dirty worktree or over any half-finished git operation - a
  cherry-pick, rebase, merge or revert with unresolved conflicts, a cherry-pick
  paused with its conflicts resolved, or one with commits still queued - so it
  never folds anything unreviewed into staging and never discards someone's
  work in progress. It names the operation it found, and only offers
  `resolved sync` for a cherry-pick, which is the only one that can finish
* a cherry-pick that fails without a conflict, a merge commit in the range being
  the usual reason, is reported as itself instead of as a conflict to resolve,
  and is told apart from a resolution waiting to be committed by whether the
  commit it stopped on is a merge
* a half-finished `git revert` of several commits is recognised as a revert
  rather than as a cherry-pick: it shares the sequencer, and its queue outlives
  `REVERT_HEAD`
* the conflict advice accounts for commits queued behind the conflict wherever
  it is printed, so a bookmark is never suggested before the rest of the range
  is applied
* an attached `-mmessage` or `--message=message` must be the last argument;
  anything after it is rejected instead of silently ignored, and `-m` with no
  message at all is an error rather than a silent fall back to the generated one
* an interrupted `git am` is named as one: it keeps its state where a rebase
  does, so the advice used to say `git rebase --abort`
* bookmarks are read through `git for-each-ref` instead of `git branch`, whose
  output carries colour when `color.branch` is forced and a `*` or `+` in front
  of a checked-out branch, either of which hid an existing bookmark
* a cherry-pick found in the preflight is only treated as this ticket's sync when
  it is on staging and its queue covers the ticket's whole range: every commit of
  production is reachable from the ticket branch, and a pick of part of the range
  would bookmark past the part nobody applied; for anybody
  else's pick the stage names the commit being applied and hands it back to git,
  rather than offering a `resolved sync` that would commit their work and
  bookmark this ticket as synced
* a `-m` message is trimmed, and one that is empty or all spaces is an error:
  git strips a blank subject, so such a message committed under the first line
  of the generated body instead
* the conflict advice says how to finish when the last commit of a range was the
  one that conflicted: `resolved sync` without `-m`, since `-m` with nothing
  staged fails before it can bookmark
* a bookmark whose push was refused no longer wedges the ticket: the next number
  is counted over local branches as well as origin's, so the stage numbers past
  the stray instead of stopping at "a branch named ABC-123-track-1 already
  exists" on every later run
* a stage that cannot fast-forward a deployed branch says so through `[ERROR]`
  and finishes with `BUILD FAILURE` instead of exiting on a bare
  `Resolve conflicts manually`
* the tracking-branch lookup matches only exact `origin/<ticket>-track-<number>`
  names, so a ticket whose name ends with another ticket's (`ABC` next to
  `XABC`) or a bookmark on a second remote can no longer be picked as the sync
  point and turned into a range git cannot resolve
* `-m "message"` is parsed positionally, which fixes the message being mangled
  when the ticket ID itself contains `-m`
* an unpushed ticket branch now reports `BUILD FAILURE` instead of
  `BUILD SUCCESS` before exiting 1
* `setup_branch`, the tracking-branch lookup and the cherry-pick range moved into
  `functions/branches.sh`, shared by `resolved`, `resolved sync` and `to-staging`
* `gitflow self update` pulls the tool's own clone, from any directory and
  without a project clone; `self` is reserved in the ticket slot and takes no
  other verb
* the update check's advice names `gitflow self update` instead of
  `git pull --rebase origin master`
* completion offers `self` and its `update` verb, and no longer prints git
  errors when used outside a clone

0.0.3.RELEASE
-------------

* `gitflow` acts on the clone of the current directory
* optional project `.gitflow` overrides the production (`WF_PROD_BRANCH`) and
  staging (`WF_STAGING_BRANCH`) branch names
* `pr` compare URL uses the project's `origin`, with branch names percent-encoded
* `config.sh` is optional and no longer holds `WF_REPO` or `WF_PROJECT_ROOT`
* templates renamed to `sample.config.sh` and `sample.dot.gitflow`

0.0.2.RELEASE
-------------

* autocompletion of local and remote branches, and of stage names
* prune local branches on stage execution
* `-m="Comment"` became `-m "Comment"`, without the equals sign
* `resolved sync` works with more than ten tracking branches
* fixed `emit` output and the use of `print_msg`, including its exit status
* `quiet` execution no longer always finishes with code 0

0.0.1.RELEASE
-------------

* stages `in-progress`, `resolved`, `deployable`
* self-update check
