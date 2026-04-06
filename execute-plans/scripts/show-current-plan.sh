#!/bin/sh
# Print the content of the first in-progress plan for a group.
#
# Usage: show-current-plan.sh [<group>]
#
# Prints nothing if no plan is currently claimed in the group. This
# surfaces the claimed plan's content inline in the ralph prompt so the
# agent sees its own plan without needing to re-read the file — mirrors
# how Claude Code echoes the approved plan back into the ExitPlanMode
# tool_result.
#
# On the first iteration of a new claim the output is empty (the claim
# happens inside the iteration). It becomes useful if multi-iteration
# claims are ever enabled.

set -eu

root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "ERROR: not inside a git repository"
  exit 0
}
cd "$root"

group="${1:-}"
db=".ralph/plans.db"

if [ ! -f "$db" ]; then
  exit 0
fi

group_esc=$(printf '%s' "$group" | sed "s/'/''/g")
first=$(sqlite3 "$db" <<SQL
.output /dev/null
PRAGMA busy_timeout = 5000;
.output stdout
SELECT path FROM plans
  WHERE group_name='$group_esc' AND state='in_progress'
  ORDER BY path LIMIT 1;
SQL
)

if [ -n "$first" ] && [ -f "$first" ]; then
  cat "$first"
fi
