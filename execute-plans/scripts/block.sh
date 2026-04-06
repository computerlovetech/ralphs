#!/bin/sh
# Mark a claimed plan as blocked with a reason.
#
# Usage: block.sh <plan-path> <reason>
#
# Only transitions rows currently in state 'in_progress'. The row stays
# in the database so a human can inspect the blocker_reason and decide
# how to resolve it (typically by updating state back to 'pending').

set -eu

if [ "$#" -lt 2 ]; then
  echo "Usage: block.sh <plan-path> <reason>" >&2
  exit 1
fi

root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "ERROR: not inside a git repository" >&2
  exit 1
}
cd "$root"

plan_path="$1"
reason="$2"
db=".ralph/plans.db"

if [ ! -f "$db" ]; then
  echo "ERROR: no database at $db (run sync.sh first)" >&2
  exit 1
fi

path_esc=$(printf '%s' "$plan_path" | sed "s/'/''/g")
reason_esc=$(printf '%s' "$reason" | sed "s/'/''/g")
sqlite3 "$db" <<SQL
.output /dev/null
PRAGMA busy_timeout = 5000;
.output stdout
UPDATE plans SET state='blocked', blocker_reason='$reason_esc'
  WHERE path='$path_esc' AND state='in_progress';
SQL
