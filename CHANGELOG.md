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
* the exit status carries the result: a run that prints `BUILD SUCCESS` exits 0
  and one that prints `BUILD FAILURE` exits 1, where every run used to exit 0
  whatever it had printed, so
  `gitflow ABC-123 to-staging && git push origin staging` pushed after a stage
  that had refused to commit. `WF_STATUS` is only ever raised now, and no later
  command lowers it again: in `in-progress` a push or a `git branch -u` that
  failed was erased by the pull that followed it, and the run ended
  `BUILD SUCCESS` with the branch left without an upstream. The ways out that
  reported nothing at all report too - the preflight checks, a missing or
  unknown stage on the command line, `pr` against an origin that is not on
  github.com, and the `emit` modes that write straight to the terminal, whose
  reachable case is a conflicting rebase in `deployable`
* `[ERROR]` prefixes every line of a multi-line message. Git's reason for
  refusing reaches the terminal through `print_err`, and only its first line was
  marked, so the advice underneath read as if the tool had stopped talking
  mid-message
* the completion loader is appended to `~/.profile` (`~/.bashrc` on Linux) and
  that file is never sourced. Sourcing it gave the shell you typed in no
  completion at all - a run cannot change the environment of the shell that
  started it - and it ran the whole of an interactive startup file inside the
  run, so a profile ending in `cd "$HOME"`, which is a common one, moved the run
  out of the project clone: the first `gitflow` in a repository reported
  `gitflow must be run inside a project clone`, and only the first, which read
  as random. The run says the loader was added and leaves reloading to you, and
  it says it only when the append went through. A startup file that is not yours
  to write - root-owned, read-only, or sitting in a read-only home - took the
  redirection down with it while the run reported the loader added anyway, and
  reported it again on every run after, because nothing had been written for the
  next run's check to find. That now ends the run with bash's own reason and the
  lines to put in the file by hand
* tab completion in the ticket slot offers branches and nothing else. It was
  filled from raw `git branch` output, so the `* ` in front of the branch you
  are on glob-expanded and offered the names of the files in the repository
  root, and in detached HEAD the four words of `(HEAD detached at 1a2b3c4)`
  came up as four tickets. Names are read through `git for-each-ref`, which
  prints refs and only refs. Production and staging are left out of the slot -
  they are exactly the two names `closed` refuses - and a project that renames
  them in `.gitflow` has its own two left out instead, which the completion
  reads the way a run does
* a tool clone whose directory name contains a space works. `$WF_DIR` was
  expanded bare, so `functions/` was never sourced and the run ended on
  `check_github: command not found` diagnosed as a missing ssh key - 127 passed
  a test that excluded only 1 - and the loader written into the startup file was
  broken from then on, erroring on every login shell. The paths are quoted, in
  the block written into the startup file as well, and the ssh check now reads
  the whole of ssh's status rather than one value of it: a greeting answers 0 or
  1 and passes, a refusal answers 255 and is told to load a key, and anything
  else is not ssh reporting on the key at all and stops the run. 127 - no `ssh`
  on the machine - was the case that went through, leaving the stage to fail at
  its own push with git's `Could not read from remote repository` standing in
  for a reason
* the command log is a file of the run's own under `$TMPDIR` instead of
  `output.log` in the tool's own directory. That directory is not the tool's to
  write in - a clone kept somewhere root-owned, which "clone somewhere
  permanent" invites - and a redirection that fails means bash runs no command
  at all, so every reporting stage came out as a bare `[ERROR]` and
  `BUILD FAILURE` with nothing said about either. The log is opened before the
  stage and the run stops if it cannot be, a command that fails without a word
  is reported as itself rather than as nothing, and two runs side by side no
  longer overwrite each other's messages - one used to report the other's
  `Switched to branch`. A leftover `output.log` in the clone is still ignored by
  git and can be deleted
* the unpushed-commits guard verifies both sides of the range it measures.
  `git log origin/ABC-123..ABC-123` fails when either ref is missing, and the
  failure went nowhere: the empty output read as nothing pending, so
  `gitflow TYPO-999 to-staging` went straight past the guard, pulled production
  and leaked git's own `fatal: ambiguous argument`. A ticket that is not there,
  or one that was never pushed, is refused by name
* a `git fetch` that fails ends the stage with git's reason under `[ERROR]`,
  where it used to be discarded. An offline run went on from whatever was last
  fetched: `closed` weighed a ticket against a stale `origin/master` and listed
  commits that had been on it for days as work that would be lost, with nothing
  to say the refs were old
* the ssh key check runs where it can mean something: every stage but `pr`,
  which only prints a compare URL and opens no connection, and only when
  `origin` is an ssh URL on github.com - the stages talk to whatever origin is,
  so on a project hosted anywhere else the answer said nothing about the run
  that followed. It is non-interactive now (`BatchMode`), so a host key nobody
  has seen before is refused instead of asked about at the start of a run, and
  ssh's reason is printed through `[ERROR]` a line at a time, where an unquoted
  `echo` collapsed a multi-line failure onto one
* the installer removes the old symlink with `rm -f` rather than `rm -rf`, which
  would have taken a directory somebody had left at `/usr/local/bin/gitflow`
  with it, and quotes the path it links to. It reads that removal now: `rm -f`
  refuses a directory, and the `ln -s` behind it then succeeded by putting the
  link inside it - `/usr/local/bin/gitflow/workflow.sh`, nothing on `PATH`,
  `gitflow` answering `permission denied`, and an installer that had printed
  nothing and exited 0. A path that cannot be replaced stops the install with
  the reason, and nothing is linked
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
* the tracking bookmarks are created with a plain `git branch`. With
  `--track` and no start point git took HEAD - the ticket branch - as the thing
  to track and wrote `branch.ABC-123-track-1.remote = .` with
  `merge = refs/heads/ABC-123`, so the bookmark followed the local ticket branch
  and a `git pull` or `git status` on it answered about the ticket's upstream. A
  bookmark records where the tip was and nothing else
* `resolved sync` prints `Now push it: git push origin staging`, the reminder
  `to-staging` prints. It used to print `git push staging`, which is not a
  command anybody can run - it reads as pushing to a remote called staging
* `deployable` prints `Now push it: git push origin master`, which it never did:
  the documented flow says all three of the stages that leave a shared branch
  ahead print the push, and this one ended on git's own
  `Successfully rebased and updated refs/heads/master`, which says a rebase
  happened and nothing about what is left to do. It is left out when the rebases
  moved production nowhere
* `deployable` and `closed` refuse a ticket branch that is not there. Neither
  looked: `deployable` leaked git's own
  `fatal: ambiguous argument 'origin/NOPE-9..NOPE-9'` from its pending-commits
  check and then failed on the checkout behind it, and `closed` matched nothing,
  deleted nothing and reported `BUILD SUCCESS`, which reads as the branches
  having been there and gone
* the rule `print_msg` draws is as wide as the terminal on a narrow one. The
  `[INFO] ` prefix is seven columns and BSD `seq` counts downwards below one, so
  a one-column terminal got `seq -6` and an eight-dash rule, and a seven-column
  one got two dashes out of `seq 0`; the dashes are counted now, and a terminal
  with no room for them gets none
* `in-progress` asks whether the branch is on origin with `[ -n "…" ]` rather
  than an unquoted `[ $EXISTS_REMOTELY ]`, whose single argument was whatever
  the listing word-split into: `gitflow HEAD in-progress` printed
  `[: ->: binary operator expected` out of git's
  `origin/HEAD -> origin/master` before the stage went on. `emitgit_abort_rebase`,
  which nothing has called since `deployable` stopped aborting rebases, is gone
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
  which pushes are not its to make, and how to finish a conflicted sync. Nothing
  in the tool itself changed
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
* `.gitflow` takes spaces around the `=`, so `WF_STAGING_BRANCH = "devel"` is
  read rather than dropped, and a line that still cannot be read stops the run
  with the file and the line named instead of `Ignoring invalid line` and a
  fallback behind it. These two keys decide which shared branch the work goes
  to: on a project that had kept its old `staging` alongside the `devel` the
  file asked for, the spaced line was skipped and `to-staging` cherry-picked the
  ticket onto `staging`, committed it there, bookmarked the round and reported
  `BUILD SUCCESS`. A file that is there and cannot be opened stops the run for
  the same reason: the read failed before the first line, nothing but bash's own
  `Permission denied` said so, and the run went on to cut the ticket from the
  branch the file had been written to replace. What the file has to say is also
  printed below the `Scanning for tasks...` banner now, rather than above the
  line that opens the run
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
* `resolved` and `deployable` refuse while a git operation is open instead of
  clearing it out of the way. `resolved` began with `git cherry-pick --abort`
  and `deployable` with `git rebase --abort`, both quiet and both before
  anything had been looked at, so a conflict resolved by hand and `git add`-ed
  went back to what staging held before the pick, with nothing printed to say
  so and `BUILD SUCCESS` at the end of the run; a cherry-pick or an interactive
  rebase you had started yourself, on whatever branch you happened to be on,
  went the same way. Each stage names the operation and the branch it is on now,
  prints how to finish it and how to abandon it, and ends `BUILD FAILURE`
  having changed nothing. The advice matches what the stage can offer: a
  cherry-pick working through this ticket's own range is a hand-resolved sync,
  which `resolved sync` finishes, so `resolved` says that and nothing else does;
  `deployable` can carry nothing into its two rebases, so it hands every
  operation back to git with that operation's own `--continue` and `--abort`
* the state a cherry-pick leaves behind once its last commit has been committed
  by hand is named rather than picked over. Nothing is queued, so there is no
  work in it, but git counts the pick as in progress and refuses the next one.
  `resolved` used to abort it - and the commit by hand had moved HEAD, so the
  abort refused to rewind and the stage picked the same range again on top of
  the commit that already carried it, leaving a fresh conflict on staging under
  `BUILD SUCCESS`. Both stages name `git cherry-pick --quit`, which keeps the
  index, and the bookmark the round may still be waiting for; `to-staging`
  clears its own as before, since it made that pick and is about to make the
  next one
* what counts as an operation in flight lives in one place, `functions/inflight.sh`,
  for the three stages that apply commits, rather than inside `to-staging`.
  Nothing about `to-staging` changed: the same messages, in the same order, for
  the same states
* `resolved` refuses a word it has no meaning for instead of quietly running
  nothing. The stage guarded its whole body with `if [ "$WF_ENV" == "" ]` and
  `workflow.sh` sourced the sync half only for exactly `sync`, so
  `gitflow ABC-123 resolved snyc` and `gitflow ABC-123 resolved -m 'msg'` fell
  between the two, did nothing at all and ended `BUILD SUCCESS`, which reads as
  a sync that happened. `sync` is the only option it takes and `-m` belongs to
  that half, so anything else is named in the error along with a usage line;
  `-m` with an empty message is an error too, rather than a fall back to
  bookmarking work that was never committed
* a cherry-pick that conflicts or fails in `resolved` ends the run
  `BUILD FAILURE`. The stage ran `git cherry-pick` without looking at the
  result and printed its advice regardless, so a `CONFLICT (content)` with
  `UU a.txt` in the tree came out as `BUILD SUCCESS` and exit 0, and a
  `&&` chain carried on from it. Stopping on a conflict is what the stage is
  for - `-n` leaves the resolution staged for review, and nothing is aborted -
  but nothing has reached staging while the round is unfinished, so the run
  reports that rather than success. It is the state `to-staging` already
  reported, so its two reporters moved to `functions/inflight.sh` instead of
  being written a second time, and `to-staging`'s own output is unchanged. An
  empty range is reported as one, where the pick used to fail with
  `error: empty commit set passed` under `BUILD SUCCESS`
* the advice `resolved` prints is runnable, and printed only where it applies.
  `Run "git cherry-pick --continue" after conflict resolution` is what git
  refuses while the resolution sits staged, which is exactly what `-n` leaves
  you with; `Run "gitflow ABC-123 resolved sync -m" and put commit message` is
  not a command anybody can run; and both of those, with
  `possible data loss if merge is incorrect` and a `git status` for `conflits`,
  were printed on every run, clean ones included. A clean pick says what is
  staged and how to commit and bookmark it, and a conflicted one gets the
  shared advice, which accounts for the commits still queued behind the
  conflict
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
