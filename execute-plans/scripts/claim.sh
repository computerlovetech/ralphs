#!/bin/sh
# Atomically claim the next pending plan for a group.
#
# Usage: claim.sh [<group>]
#
# Prints the path of the claimed plan on success, or the literal string
# `no plans remaining` if nothing was available. Never errors on an
# empty queue — the ralph loop uses the printed value to decide whether
# to stop.
#
# Coordination: SQLite serializes concurrent writers on the database
# file, so the UPDATE ... WHERE path = (subquery) AND state='pending'
# ... RETURNING path either claims exactly one row or returns nothing.
# Two racing agents therefore always pick different plans — no retry
# loop required.

set -eu

root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "ERROR: not inside a git repository" >&2
  exit 0
}
cd "$root"

group="${1:-}"
db=".ralph/plans.db"

if [ ! -f "$db" ]; then
  echo "no plans remaining"
  exit 0
fi

agent="${RALPH_AGENT_ID:-$(hostname)-$$}"

group_esc=$(printf '%s' "$group" | sed "s/'/''/g")
agent_esc=$(printf '%s' "$agent" | sed "s/'/''/g")

result=$(sqlite3 "$db" <<SQL
.output /dev/null
PRAGMA busy_timeout = 5000;
.output stdout
UPDATE plans
SET state='in_progress',
    claimed_by='$agent_esc',
    claimed_at=unixepoch()
WHERE path = (
  SELECT path FROM plans
  WHERE group_name='$group_esc' AND state='pending'
  ORDER BY path
  LIMIT 1
)
AND state='pending'
RETURNING path;
SQL
)

if [ -z "$result" ]; then
  echo "no plans remaining"
else
  printf '%s\n' "$result"
fi
