#!/bin/sh
# Mark a claimed plan as done.
#
# Usage: finalize.sh <plan-path>
#
# Only transitions rows currently in state 'in_progress'. If the row is
# not in that state (e.g. it was never claimed, or already finalized),
# the UPDATE is a no-op and this script exits silently.

set -eu

if [ "$#" -lt 1 ]; then
  echo "Usage: finalize.sh <plan-path>" >&2
  exit 1
fi

root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "ERROR: not inside a git repository" >&2
  exit 1
}
cd "$root"

plan_path="$1"
db=".ralph/plans.db"

if [ ! -f "$db" ]; then
  echo "ERROR: no database at $db (run sync.sh first)" >&2
  exit 1
fi

path_esc=$(printf '%s' "$plan_path" | sed "s/'/''/g")
sqlite3 "$db" <<SQL
.output /dev/null
PRAGMA busy_timeout = 5000;
.output stdout
UPDATE plans SET state='done', completed_at=unixepoch()
  WHERE path='$path_esc' AND state='in_progress';
SQL
