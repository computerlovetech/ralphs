# ralphs

A collection of ralphs following the [ralphify](https://ralphify.co/docs/) format.

This repo will be updated on an ongoing basis with new ralphs.

## execute-plans

Runs through a queue of plan files (one plan per `.md` file) and
implements them one at a time. Designed to be run as one agent or as
several agents in parallel on the same machine.

### Directory layout

```
plans/
  001-foo.md              <- ungrouped plans (default)
  002-bar.md
  groups/
    urgent/
      001-hotfix.md       <- plans for the "urgent" group
    refactor/
      ...
.ralph/
  plans.db                <- SQLite state (gitignored)
```

Plans dropped directly into `plans/` are picked up by any ralph
started without a `--group` arg. Plans under `plans/groups/<name>/`
are picked up only by ralphs started with `--group <name>`.

Plan files never move. State (pending / in-progress / done / blocked)
lives in `.ralph/plans.db` and is updated by the scripts in
`execute-plans/scripts/`.

### Running

```sh
# Work on ungrouped plans
ralph execute-plans

# Work on a specific group
ralph execute-plans --group urgent

# Multiple agents in parallel on the same group
ralph execute-plans --group urgent &
ralph execute-plans --group urgent &
```

### Steering work to a specific ralph

To direct a new batch of plans at one running ralph without affecting
others, drop them into that ralph's group directory:

```sh
# Hand work to the "urgent" ralph
mv new-hotfix.md plans/groups/urgent/
```

The next iteration's `sync.sh` will index the new file as pending in
the `urgent` group.

To reassign an already-pending plan from one ralph to another, just
move the file:

```sh
mv plans/groups/refactor/007.md plans/groups/urgent/007.md
```

On their next iterations, the `refactor` ralph's `sync.sh` drops the
stale row (the file no longer exists there) and the `urgent` ralph's
`sync.sh` inserts it as pending. Only `pending` rows are reconciled
this way — active claims and historical `done` / `blocked` rows are
left alone.

### Parallel safety

Multiple ralphs in the same group coordinate through SQLite:

- Each iteration's first step is `sync.sh`, which indexes any new
  plan files into `.ralph/plans.db`.
- Claiming a plan is a single atomic `UPDATE ... WHERE state='pending'
  ... RETURNING path` inside `claim.sh`. SQLite's write lock
  serializes concurrent writers, so if two agents race, each one
  picks a different plan — there is no retry loop.
- Agents never read or modify files in other groups, and never touch
  in-progress claims that aren't their own.
- Ralph never runs `git fetch`, `git reset --hard`, or `git push`.
  Implementation commits (`feat:`, `fix:`, ...) are made locally; a
  human can publish them afterwards if desired.

Requirements:

- `sqlite3` CLI (bundled on macOS, available in every mainstream
  Linux package manager).
- All parallel agents must run from the same working directory so
  they share one `.ralph/plans.db` file.

## bug-hunter

Finds and fixes real bugs in a Python codebase (uses `uv`, `pytest`,
`ty`, `ruff`). Writes a failing regression test, fixes the bug,
verifies everything still passes. One bug per iteration.

## improve-codebase

Makes non-functional improvements to a Python codebase (code quality,
structure, readability, dead code removal, test coverage). One
improvement per iteration.
