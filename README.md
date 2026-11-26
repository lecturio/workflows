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

Three `gitflow` stages, with the pull request opened and merged in between by
the [GitHub CLI](https://cli.github.com):

```
in-progress  →  gh pr create  →  to-staging  →  gh pr merge --rebase  →  closed
                                  (repeat)
```

```bash
gitflow ABC-123 in-progress    # create or switch to the ticket branch
gh pr create --base master     # open the pull request for review
gitflow ABC-123 to-staging     # put the new commits on staging
                               # (--verify "cmd" checks them before the commit)
gh pr merge ABC-123 --rebase   # ship it, once it is accepted on staging
gitflow ABC-123 closed         # delete the ticket branches
```

Only `to-staging` repeats: you run it again for every round of commits while the
ticket is being reviewed on staging. Everything else happens once per ticket.

`resolved` and `resolved sync` are **deprecated**. They split `to-staging` into
two steps, and nothing but a conflicted sync needs them now. `pr` and
`deployable` were **removed** in favour of `gh pr create` and
`gh pr merge --rebase`. All of them are covered in
[docs/deprecated.md](docs/deprecated.md).

One further command acts on the tool itself rather than on a ticket:

```bash
gitflow self update           # pull the newest gitflow into your clone
```

Requirements
------------

* bash and git, on macOS or Linux
* an SSH key loaded in your agent when the project's `origin` is an ssh URL on
  github.com: every stage checks it with
  `ssh -o BatchMode=yes -T git@github.com` before it starts, and that check never
  prompts. A greeting answers 0 or 1 and passes; a refusal answers 255 and asks
  for the key; any other status is not `ssh` reporting on the key at all - 127 is
  `ssh` missing - and stops the run just the same, rather than leave it to fail
  at the push
* the [GitHub CLI](https://cli.github.com), logged in (`gh auth login`), for
  opening and merging the pull request
* "Allow rebase merging" on the GitHub repository. Turn squash merging off while
  you are there: a squash commit matches none of the ticket's commits, so
  `closed` takes every squashed ticket for unmerged work and asks before
  deleting it
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
your `PATH` would leave it unable to find `functions/`. Whatever is at that path
already is removed first, and the installer stops if it cannot be - a directory
somebody left there is the usual case - rather than link inside it and report
nothing.

The first `gitflow` run also appends a completion loader to `~/.profile`
(`~/.bashrc` on Linux) and says so; reload that file, or open a new shell, to
pick it up. A startup file the run cannot write stops it, with the lines to add
by hand. See [shell completion](docs/troubleshooting.md#shell-completion).

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

3. **Open the pull request** with the GitHub CLI, from the ticket branch, into
   production. Open it as soon as there is something to read, so the code
   review runs while the ticket is being tested on staging. Leave it open until
   the ticket is accepted there: merging it in step 5 is what updates
   production.

   ```bash
   gh pr create --base master
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

5. **Ship it.** Once the ticket is accepted on staging, merge the pull request.
   `--rebase` puts the ticket's commits on production one by one, with no merge
   commit, and GitHub records the PR as merged:

   ```bash
   gh pr merge ABC-123 --rebase
   ```

   Never `--squash` (see the requirements), and leave out `--delete-branch`:
   step 6 deletes the ticket branch together with its bookmarks. When GitHub
   says the branch cannot be rebased, it conflicts with production; see
   [the merge conflicts](docs/troubleshooting.md#the-pull-request-cannot-be-rebased).

6. **Clean up.** Deletes the ticket branch and its tracking branches, local and
   remote. The deployed branches are never deleted, and a branch carrying commits
   production has not got is listed and waits for a `y`.

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

Either key may be left out, spaces around the `=` are fine, and the value may be
quoted or bare. Keys in the file win over the environment; keys that are absent
fall back to the environment, then to the defaults above. A line that is not
`KEY=value`, a `#` comment or blank stops the run and is named, rather than being
skipped with `master` and `staging` used behind it, and so does a file that is
there and cannot be read.

Using it from an agent
----------------------

`skills/gitflow` is a Claude Code skill that teaches an agent this workflow: the
stages and what each one leaves behind, opening the pull request and merging it
only on your word, the pushes it must not make on your behalf, and how to finish
a sync or a merge that conflicted. Link it into your Claude Code skills, from
this clone:

```bash
mkdir -p ~/.claude/skills
ln -s "$PWD/skills/gitflow" ~/.claude/skills/gitflow
```

A link rather than a copy, because the skill describes the workflow as it
stands: `gitflow self update` then updates the skill along with the tool, where
a copy goes on describing stages that may have been removed since. Moving the
clone breaks the link the same way it breaks the `gitflow` install.

Checking a change
-----------------

`test/smoke.sh` runs the whole flow — `in-progress`, `to-staging`, a rebase-merge
the way GitHub makes one, `closed` — against repositories it builds and throws
away, and checks the exit status of each stage against what its banner said:

```bash
./test/smoke.sh                  # the clone it lives in
./test/smoke.sh /path/to/clone   # some other one
```

It touches nothing of yours: the project, its origin and a copy of the tool are
built under a temporary directory with `HOME`, `TMPDIR` and `PATH` pointed into
it, and the whole lot is removed when the run ends. It exits 0 when every check
passed and names the ones that did not.

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
