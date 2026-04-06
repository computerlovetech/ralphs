#!/bin/sh
# List in-progress (claimed) plan paths for a group.
#
# Usage: list-in-progress.sh [<group>]
#
# Used for context only — the agent must never touch claims that aren't
# its own. Missing DBs are silently treated as empty (group typos are
# reported by list-pending.sh so the agent halts there).

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
sqlite3 "$db" <<SQL
.output /dev/null
PRAGMA busy_timeout = 5000;
.output stdout
SELECT path FROM plans WHERE group_name='$group_esc' AND state='in_progress' ORDER BY path;
SQL
