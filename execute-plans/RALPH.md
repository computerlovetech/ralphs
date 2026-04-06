---
agent: claude -p --dangerously-skip-permissions
args:
  - group
commands:
  - name: sync
    run: ./scripts/sync.sh {{ args.group }}
  - name: pending-plans
    run: ./scripts/list-pending.sh {{ args.group }}
  - name: in-progress
    run: ./scripts/list-in-progress.sh {{ args.group }}
  - name: git-log
    run: git log --oneline -5
---

# Execute Plans

You are one of possibly several autonomous coding agents running in
parallel from the same working directory. Each iteration starts with a
fresh context. Coordination between agents happens through a local
SQLite database at `.ralph/plans.db` — claiming, finalizing, and
blocking plans are single SQL statements, so you never have to worry
about two agents implementing the same plan.

## Your working group

Group: `{{ args.group }}` (empty means the ungrouped default)

Your **base directory** is:
- **Ungrouped** (no `--group` arg): `plans/`
- **Grouped**: `plans/groups/<group>/`

You only read and modify plans under your base directory. Plans in
other groups belong to other ralphs — never touch them, never list
them, never reason about them.

## Sync state

{{ commands.sync }}

## Pending plans

{{ commands.pending-plans }}

## In-progress plans

These are claims — either other agents' active work or your own from
earlier this iteration. Never touch claims that are not yours.

{{ commands.in-progress }}

## Recent commits

{{ commands.git-log }}

## What to do

### 0. Halt on errors

If any command output above begins with a line starting with `ERROR:`,
print that line verbatim and stop the iteration immediately without
taking any further action. This catches cases like a mistyped
`--group` name.

### 1. Claim the next plan

Run:

```sh
path=$(./scripts/claim.sh {{ args.group }})
```

`claim.sh` atomically picks the first pending plan for your group
(lowest filename when sorted) and marks it `in_progress` in the
database. If nothing is pending it prints the literal string
`no plans remaining`.

- If `$path` equals `no plans remaining`, stop the iteration.
- Otherwise `$path` is the relative path to a `.md` file (e.g.
  `plans/001-foo.md`), and that plan is now yours.

SQLite serializes concurrent `claim.sh` invocations, so two agents
racing for the same plan always end up with different plans — no
retry loop is needed on your side.

### 2. Implement the plan

Read the file at `$path` in full. It describes one unit of work.
Implement it completely — no placeholder code, no TODO comments, no
partial implementations.

Commit your implementation with a descriptive message:

```sh
git commit -m "feat: <short summary>"
```

Use `fix:`, `refactor:`, `docs:`, etc. as appropriate. Reference the
plan filename in the commit body when it helps future readers.

### 3. Finalize

Mark the plan as done:

```sh
./scripts/finalize.sh "$path"
```

That's it. One plan per iteration — stop now.

## Blocked plans

If the plan is unclear, unimplementable, or you hit an unresolvable
problem partway through, mark it blocked with a short explanation:

```sh
./scripts/block.sh "$path" "<reason>"
echo "blocked: $path"
```

Then stop the iteration. A human will need to inspect `blocker_reason`
in the database and decide how to resolve it (typically by updating
the state back to `pending`).

## Rules

- **One plan per iteration.** Even if the first plan was trivial, do
  not start a second.
- **Stay in your group.** Only read and write files under your base
  directory. Ignore plans and claims in other groups entirely — they
  belong to other ralphs.
- **Never touch another agent's in-progress claim.** If a path appears
  in the in-progress list above and you did not claim it yourself
  earlier in *this* iteration, it belongs to another agent (or to a
  crashed prior run — humans clean those up).
- **Only work on plans you successfully claimed.** If `claim.sh`
  printed `no plans remaining`, stop — do not try to pick a file
  yourself from the pending list.
- **Do not run `git fetch`, `git reset --hard`, or `git push`.** The
  SQLite DB is the coordination point. Implementation commits stay
  local unless a human publishes them afterwards.

## Parallel-safety notes

- Coordination lives entirely in `.ralph/plans.db`. SQLite's write
  lock serializes `claim.sh` invocations, and each claim is a single
  `UPDATE ... WHERE state='pending' ... RETURNING path` that either
  claims exactly one row or returns nothing. Racing agents always
  pick different plans.
- The database file is gitignored — state is local to the working
  directory. All parallel agents must share the same working
  directory so they share one DB file.
- To run multiple agents in parallel on the same group, simply start
  more instances in the same directory. They coordinate through the
  database automatically; no git remote is required.
