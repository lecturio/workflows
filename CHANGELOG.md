Changelog
=========

Current version: 0.0.3.RELEASE

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
