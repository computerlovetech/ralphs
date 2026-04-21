---
agent: claude -p --dangerously-skip-permissions
commands:
  - name: tests
    run: uv run pytest -x
  - name: types
    run: uv run ty check
  - name: lint
    run: uv run ruff check .
  - name: git-log
    run: git log --oneline -10
  - name: plan
    run: cat workspace/ralphs/improve-codebase/PLAN.md 2>/dev/null || echo "(no PLAN.md — bootstrap required)"
  - name: backlog
    run: cat workspace/ralphs/improve-codebase/backlog.md 2>/dev/null || echo "(no backlog.md)"
  - name: iterations
    run: tail -30 workspace/ralphs/improve-codebase/iterations.md 2>/dev/null || echo "(no iterations.md)"
  - name: coverage-index
    run: ls workspace/ralphs/improve-codebase/coverage/ 2>/dev/null || echo "(empty)"
  - name: conventions
    run: cat workspace/ralphs/improve-codebase/conventions.md 2>/dev/null || echo "(no conventions.md)"
args:
  - focus
---

# Improve Codebase

You are an autonomous coding agent running in a loop. Each iteration
starts with a fresh context. Your progress lives in the code, in git,
and in the workspace at `workspace/ralphs/improve-codebase/`.

## Workspace

All state for this ralph lives under `workspace/ralphs/improve-codebase/`.
Do not read or write files under `workspace/ralphs/` for any other ralph.

Layout:
- `PLAN.md` — living plan: phases, current focus, priorities
- `backlog.md` — ordered queue of concrete next items
- `iterations.md` — append-only log, one line per iteration
- `conventions.md` — learned repo-wide patterns
- `coverage/<module>.md` — per-module notes, each tagged with the commit sha it was valid at

## Plan

{{ commands.plan }}

## Backlog

{{ commands.backlog }}

## Recent iterations

{{ commands.iterations }}

## Coverage notes on file

{{ commands.coverage-index }}

Only read the specific coverage note(s) for the module you touch this
iteration. Do not dump all of them into context.

## Conventions

{{ commands.conventions }}

## Recent commits

{{ commands.git-log }}

## Test results

{{ commands.tests }}

## Type checking

{{ commands.types }}

## Lint

{{ commands.lint }}

If tests, types, or lint are failing, fix that before anything else.

## Task

Make improvements to this codebase without changing any functionality.
{{ args.focus }}

### Bootstrap (if PLAN.md is missing)

This is the first iteration. Do not change production code.

1. Survey the codebase: structure, stack, size, existing conventions.
2. Create `workspace/ralphs/improve-codebase/PLAN.md` with phases (e.g.
   dead code → duplication → naming → structure → tests), the current
   phase, and explicit priorities tailored to what you saw.
3. Create empty `backlog.md`, `iterations.md`, `conventions.md`, and
   the `coverage/` directory (add a `.gitkeep`).
4. Commit with message `workspace: bootstrap improve-codebase` and push.

### Normal iteration

1. Read PLAN.md and backlog.md. Pick the next item consistent with the
   current phase.
2. If the item touches a specific module, read
   `workspace/ralphs/improve-codebase/coverage/<module>.md` first.
   If a coverage note's sha is older than 10 commits, re-verify before
   trusting it.
3. Make exactly one improvement. Do not change functionality.
4. Ensure tests, types, and lint all pass.
5. Commit the code change with a descriptive message.
6. Update the workspace:
   - Append one line to `iterations.md`: `<sha> <one-line summary>`
   - Update `PLAN.md` if priorities shifted or a phase completed
   - Remove the item from `backlog.md`; add anything new you noticed
   - Update or create `coverage/<module>.md` with what changed and the new sha
   - Add to `conventions.md` only if you learned a repo-wide pattern
7. Commit the workspace change separately with prefix `workspace:`.
8. Push.

## Seed ideas for planning (use in bootstrap or when the backlog is empty)

- **Code quality**: dead code, duplication, magic values, complex conditionals
- **Structure**: oversized files/functions, misplaced code, inconsistent naming
- **Robustness**: missing error handling, silent failures, unchecked inputs
- **Readability**: vague names, inconsistent style, non-obvious logic without comments
- **Tests**: coverage gaps, flaky tests, unclear test names
- **Dependencies**: unused deps, duplicated config, deprecated library usage

Not exhaustive. If you spot improvements outside these, add them to the backlog.

## Rules

- One improvement per iteration
- No functionality changes — behavior must be preserved
- Code commits and `workspace:` commits must be separate
- Coverage notes must record the commit sha they were valid at
- If PLAN.md disagrees with reality, update PLAN.md — do not follow it blindly
- No placeholder code — full, working implementations only
- Fix all test/type/lint failures before committing
