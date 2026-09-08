Changelog
=========

Current version: 0.0.4.SNAPSHOT

0.0.4.SNAPSHOT
--------------

* new stage `to-staging` puts a ticket on staging in one command: it cherry-picks,
  commits and bookmarks, writing a commit message that names the commits it picked
  (`ABC-123 a1b2c3d 4e5f6a7`), and leaves the push to you
* `to-staging` commits nothing when the cherry-pick conflicts, and refuses to
  start on a dirty worktree or over an unresolved conflict, so it never folds
  anything unreviewed into staging
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
