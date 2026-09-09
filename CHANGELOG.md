Changelog
=========

Current version: 0.0.4.SNAPSHOT

0.0.4.SNAPSHOT
--------------

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
  the usual reason, is reported as itself instead of as a conflict to resolve
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
