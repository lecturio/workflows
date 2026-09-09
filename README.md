gitflow
=======

`gitflow` walks one ticket from a fresh branch to a deployed change. You give it a
ticket ID and the stage you want; it runs the git work for that stage.

It assumes a project with two deployed branches:

| Role | Default branch | Deployed to |
| --- | --- | --- |
| production | `master` | live server |
| staging | `staging` | staging server |

A ticket branch is cut from production, pushed onto staging as often as you like
while the work is reviewed there, and folded back into production once it is
accepted. The branch is named after the ticket, so the ID you pass is also the
branch name.

The stages
----------

Five stages, in the order a ticket runs them:

```
in-progress  →  pr  →  to-staging  →  deployable  →  closed
                        (repeat)
```

```bash
gitflow ABC-123 in-progress   # create or switch to the ticket branch
gitflow ABC-123 pr            # print the pull-request link for review
gitflow ABC-123 to-staging    # put the new commits on staging
gitflow ABC-123 deployable    # fold the ticket into production
gitflow ABC-123 closed        # delete the ticket branches
```

Only `to-staging` repeats: you run it again for every round of commits while the
ticket is being reviewed on staging. The other four happen once per ticket.

`resolved` and `resolved sync` are **deprecated**. They split `to-staging` into
two steps, and nothing but a conflicted sync needs them now — see
[docs/deprecated.md](docs/deprecated.md).

One further command acts on the tool itself rather than on a ticket:

```bash
gitflow self update           # pull the newest gitflow into your clone
```

Requirements
------------

* bash and git, on macOS or Linux
* an SSH key loaded in your agent: every run starts with `ssh -T git@github.com`
* a clone of the project, with the production branch checked out
* rights to write into `/usr/local/bin` for the install step, which on a default
  macOS or Linux box means root; the installer runs `sudo` for you

Install
-------

Clone this repo somewhere permanent, then:

```bash
./install/install.sh
```

This symlinks `/usr/local/bin/gitflow` to `workflow.sh` inside the clone, so don't
move the clone afterwards. All three of the installer's commands are prefixed with
`sudo`, so it asks for your password even on machines where you own
`/usr/local/bin` already. That path is not a free choice either: `workflow.sh`
locates its own directory by reading this specific symlink, so a link elsewhere on
your `PATH` would leave it unable to find `functions/`.

The first `gitflow` run also appends a completion loader to `~/.profile`
(`~/.bashrc` on Linux); see
[shell completion](docs/troubleshooting.md#shell-completion).

Every run compares this clone with its own remote and stops if the two differ in
either direction, so keep it up to date and free of local commits:

```bash
gitflow self update
```

Run `gitflow` from anywhere inside the project you want it to act on. It reads the
repository root and the `origin` URL from your current directory, so there is
nothing to set up per project.

Quick start: one ticket, end to end
-----------------------------------

1. **Start.** Creates `ABC-123` from production, pushes it and sets its upstream.
   Re-run it any time to get back on the branch.

   ```bash
   gitflow ABC-123 in-progress
   ```

2. **Work.** Commit and push with plain git. `to-staging` refuses to run while
   the ticket branch has unpushed commits.

   ```bash
   git commit -am "ABC-123 add the thing" && git push
   ```

3. **Open the pull request.** Prints the compare URL into production and runs no
   git commands. Open it as soon as there is something to read, so the code
   review runs while the ticket is being tested on staging. The PR is a review
   vehicle: leave it unmerged, step 5 is what updates production.

   ```bash
   gitflow ABC-123 pr
   ```

4. **Put it on staging.** Cherry-picks the commits added since your last sync,
   commits them with a message naming those commits, and stops. The push is
   yours:

   ```bash
   gitflow ABC-123 to-staging
   git log -1 --format=%s staging     # ABC-123 a1b2c3d 4e5f6a7
   git push origin staging
   ```

   Repeat steps 2 and 4 for as long as the ticket is being reviewed on staging.
   The pull request from step 3 picks up the new commits on its own; it does not
   have to be opened again.

   It commits nothing when the cherry-pick conflicts, and nothing when your
   worktree is dirty. Pass `-m "..."` to write the subject yourself; the commits
   then move into the message body. When the cherry-pick does conflict, the stage
   prints the commands that finish it — see
   [conflicts](docs/troubleshooting.md#conflicts).

5. **Ship it.** Rebases the ticket onto production, then moves production onto the
   ticket. Review, then push yourself:

   ```bash
   gitflow ABC-123 deployable
   git log --oneline -5
   git push origin master
   ```

6. **Clean up.** Deletes the ticket branch and its tracking branches, local and
   remote, immediately and without asking.

   ```bash
   gitflow ABC-123 closed
   ```

Per-repo branch names
---------------------

If a project doesn't use `master` and `staging`, commit a `.gitflow` file at its
repository root so the whole team gets the same names (template:
[sample.dot.gitflow](sample.dot.gitflow)):

```
WF_PROD_BRANCH=main
WF_STAGING_BRANCH=devel
```

Either key may be left out. Keys in the file win over the environment; keys that
are absent fall back to the environment, then to the defaults above.

Documentation
-------------

* [docs/concepts.md](docs/concepts.md) — how the branches relate, what the
  `-track-` branches are for, and what the tool leaves to you
* [docs/commands.md](docs/commands.md) — every stage in detail, including the git
  commands it runs, plus `gitflow self update`
* [docs/troubleshooting.md](docs/troubleshooting.md) — error messages, conflict
  recovery, re-syncing after staging is recreated
* [docs/deprecated.md](docs/deprecated.md) — `resolved` and `resolved sync`, what
  replaced them, and the reference kept for the conflict case
* [Additional commands during feature development](https://github.com/lecturio/workflows/wiki/Additional-commands-during-feature-development) (wiki)
* [CHANGELOG.md](CHANGELOG.md)
