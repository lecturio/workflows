Workflows
=========

Git workflow for application with staging and live environment.
All features are merged with staging branch and from there- released on staging system.
When feature is ready - it is merged with master and from there released to live system.

# Usage

Create copy of config-empty.sh to config.sh and edit following values:

* `WF_REPO` - git remote respository
* `WF_PROJECT_ROOT` - directory where project is cloned

Tool expects that you have previosly cloned master to your local system.

Tool works with ssh so you need to have setup ssh-key-paris.

`WF_DEBUG` and `WF_VERBOSE` are not used at the moment.

You need to get something like that:

```
#!/bin/bash
## configuration values

export WF_REPO=git@github.com:lecturio/workflows.git
export WF_PROJECT_ROOT="/projects/workflows"
export WF_DEBUG=0
export WF_VERBOSE=0

```

# Install

```bash
cd workflows
./install/install.sh
```

Creates symlink in `/usr/local/bin/gitflow`.

From now on `workflow.sh` command can be replaced with `gitflow`.

You can use `gitflow` in your current project dir.

# Git Commands Manifesto

Please check follwoing guide

https://github.com/lecturio/workflows/wiki/Additional-commands-during-feature-development

# Server Setup

* live server
* staging server

# Branch setup

* master- deployed on `live server`
 * rebase with feature (one time)
* staging- deployed on `staging server`
* feature
 * created from master
 * cherry-picked - until feature is approved to staging (multiple times)
 * rebase with master - retrieve changes from master (multiple times)

# Goals

Tool have following pattern: ./workflow.sh [FEATURE] [GOAL] [OPTION] where:

* FEATURE - XXX-001
* GOAL
 * in-progress
 * resolved, option sync
 * deployed
 * closed
* OPTION - some goals have additional options like `resolved`

## In progress

Creates feature branch from master branch.

### Goal
```bash
gitflow XXX-001 in-progress
```

* Create branch XXX-001 (if branch is missing on remote and in local repo). Push branch to remote.
* Switch branch from local or checkout from remote.
* Update branch from remote feature branch.


## Resolved

Review merge files before make commit to staging branch.

### Goal

```bash
gitflow XXX-001 resolved
```

Review cherry-pick changes. If merge is ok - they are ready for commit.

### Conflict
Resolving of conflicts - use `git add` or `git rm`. When conflict is resolved move to `git cherry-pick --continue`.

Use `git status` to review modified files.
Abort - restart goal.
Changes - `git log` to ensure status of your changes.

After resolving run:

```bash
gitflow XXX-001 resolved sync
```

## Resolved Sync

Option to commit changes to staging and push to staging.
Changes can be commit from IDE or with `git commit -am "Commit message"

### Goal
```bash
gitflow XXX-001 resolved sync
```

Creates tracking branches and push changes to staging remote.

```
gitflow XXX-001 resolved sync -m="Commit message"

```

Commit changes to staging branch and push changes to staging remote.

## Deployed

Sync changes from feature branch to master branch. One-time operation.
After is ready branch must be `closed`. This is end of the working cycle.

### Goal

```bash
gitflow XXX-001 deployed
```

Rebase master to feature branch.
Rebase feature branch to master branch.
Review your changes.
Push to master must be created manually - from IDE or with `git push origin master`.

### Conflict

Most likely conflicts are on first step - rebase master to feature branch. Rebase feature branch to master usually are fast-forwarded.

Resolving of conflicts - use `git add` or `git rm`. When conflict is resolved move to `git rebase --continue`.

Use `git status` to check where are the conflicts and on with step (rebase master to feature branch or rebase feature to master).

Abort - restart goal.
Changes - `git log` to ensure status of your changes.

After resolving conflict run again 

```bash
gitflow XXX-001 deployable
```

### Closed

run

```bash
gitflow XXX-001 closed
```

script will pop out the code which needs to be executed to delete local and remote branch

# Flow

* Create feature branch from master
* Push feature as remote feature branch
* Working on the feature (commit and push)
* Rebase with master during feature development to be kept up to date
* Cherry-pick new changes to staging (multiple times)
* Rebase master with feature (end of flow). Start from begging.


#TODO

* `close` goal is not implemented
* `staging` must be called `devel`
