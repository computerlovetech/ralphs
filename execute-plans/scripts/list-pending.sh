#!/bin/sh
# List pending plan paths for a group (or for the ungrouped default).
#
# Usage: list-pending.sh [<group>]
#   No arg  → lists pending rows with group_name=''
#   <group> → lists pending rows with group_name='<group>'
#
# If a non-empty group is given but its directory does not exist, prints
# an "ERROR:" line so the agent can surface the typo instead of silently
# treating it as "no plans remaining".

set -eu

root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "ERROR: not inside a git repository"
  exit 0
}
cd "$root"

group="${1:-}"

if [ -n "$group" ] && [ ! -d "plans/groups/$group" ]; then
  echo "ERROR: group '$group' does not exist (expected directory: plans/groups/$group/)"
  echo "Create it first, or run without --group to work on ungrouped plans."
  exit 0
fi

db=".ralph/plans.db"
if [ ! -f "$db" ]; then
  # DB hasn't been created yet — sync.sh will create it. No rows means
  # nothing pending, which is a normal (non-error) state.
  exit 0
fi

group_esc=$(printf '%s' "$group" | sed "s/'/''/g")
sqlite3 "$db" <<SQL
.output /dev/null
PRAGMA busy_timeout = 5000;
.output stdout
SELECT path FROM plans WHERE group_name='$group_esc' AND state='pending' ORDER BY path;
SQL
