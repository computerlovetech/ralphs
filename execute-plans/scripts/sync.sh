#!/bin/sh
# Sync filesystem state into .ralph/plans.db for a group.
#
# - Ensures the DB and schema exist (idempotent, WAL enabled).
# - INSERT OR IGNORE every top-level .md file in the group's directory
#   as a pending row.
# - DELETE any *pending* row whose file no longer exists on disk, so
#   moves and deletions don't leave ghost rows. Rows in states
#   in_progress / done / blocked are left untouched.
#
# Usage: sync.sh [<group>]
#   No arg  → syncs plans/*.md
#   <group> → syncs plans/groups/<group>/*.md
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

if [ -z "$group" ]; then
  base="plans"
else
  base="plans/groups/$group"
  if [ ! -d "$base" ]; then
    echo "ERROR: group '$group' does not exist (expected directory: $base/)"
    echo "Create it first, or run without --group to work on ungrouped plans."
    exit 0
  fi
fi

mkdir -p .ralph
db=".ralph/plans.db"

# Escape the group name for single-quoted SQL literals.
group_esc=$(printf '%s' "$group" | sed "s/'/''/g")

# Gather current .md files in the base directory (top-level only).
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
find "$base" -mindepth 1 -maxdepth 1 -type f -name '*.md' ! -name 'README.md' 2>/dev/null \
  | sort > "$tmp"

# Build and run a single SQL script: schema + temp table of current files
# + INSERT OR IGNORE + DELETE stale pending rows, all in one connection so
# the TEMP table is visible across statements.
{
  cat <<'SQL'
.output /dev/null
PRAGMA busy_timeout = 5000;
PRAGMA journal_mode=WAL;
.output stdout
CREATE TABLE IF NOT EXISTS plans (
  path           TEXT PRIMARY KEY,
  group_name     TEXT NOT NULL DEFAULT '',
  state          TEXT NOT NULL DEFAULT 'pending'
                 CHECK(state IN ('pending','in_progress','done','blocked')),
  claimed_by     TEXT,
  claimed_at     INTEGER,
  completed_at   INTEGER,
  blocker_reason TEXT,
  created_at     INTEGER NOT NULL DEFAULT (unixepoch())
);
CREATE INDEX IF NOT EXISTS idx_plans_group_state_path
  ON plans(group_name, state, path);
BEGIN;
CREATE TEMP TABLE current_files(path TEXT PRIMARY KEY);
SQL

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    f_esc=$(printf '%s' "$f" | sed "s/'/''/g")
    printf "INSERT INTO current_files(path) VALUES('%s');\n" "$f_esc"
  done < "$tmp"

  cat <<SQL
INSERT OR IGNORE INTO plans(path, group_name)
  SELECT path, '$group_esc' FROM current_files;
DELETE FROM plans
  WHERE group_name = '$group_esc'
    AND state = 'pending'
    AND path NOT IN (SELECT path FROM current_files);
COMMIT;
SQL
} | sqlite3 "$db" >/dev/null
