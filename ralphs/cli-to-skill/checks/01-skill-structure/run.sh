#!/usr/bin/env bash
set -euo pipefail

# Find all SKILL.md files in .claude/skills/
skill_files=$(find .claude/skills -name "SKILL.md" -not -path "*/new-ralph/*" 2>/dev/null || true)

if [ -z "$skill_files" ]; then
  echo "ERROR: No SKILL.md files found in .claude/skills/ (excluding new-ralph)"
  exit 1
fi

errors=0

while IFS= read -r skill_file; do
  dir=$(dirname "$skill_file")
  dir_name=$(basename "$dir")

  echo "Checking: $skill_file"

  # Check frontmatter exists
  if ! head -1 "$skill_file" | grep -q "^---$"; then
    echo "  ERROR: Missing YAML frontmatter"
    errors=$((errors + 1))
    continue
  fi

  # Extract frontmatter
  frontmatter=$(sed -n '/^---$/,/^---$/p' "$skill_file")

  # Check required fields
  if ! echo "$frontmatter" | grep -q "^name:"; then
    echo "  ERROR: Missing required 'name' field"
    errors=$((errors + 1))
  fi

  if ! echo "$frontmatter" | grep -q "^description:"; then
    echo "  ERROR: Missing required 'description' field"
    errors=$((errors + 1))
  fi

  # Check name matches directory
  name=$(echo "$frontmatter" | grep "^name:" | sed 's/^name: *//' | tr -d '"' | tr -d "'")
  if [ -n "$name" ] && [ "$name" != "$dir_name" ]; then
    echo "  ERROR: name '$name' does not match directory name '$dir_name'"
    errors=$((errors + 1))
  fi

  # Check name format (lowercase alphanumeric + hyphens)
  if [ -n "$name" ] && ! echo "$name" | grep -qE '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$'; then
    echo "  ERROR: name '$name' must be lowercase alphanumeric + hyphens, no leading/trailing hyphens"
    errors=$((errors + 1))
  fi

  # Check line count
  line_count=$(wc -l < "$skill_file")
  if [ "$line_count" -gt 500 ]; then
    echo "  WARNING: SKILL.md is $line_count lines (recommended max: 500)"
    errors=$((errors + 1))
  fi

  # Check description length
  desc=$(echo "$frontmatter" | grep "^description:" | sed 's/^description: *//' | tr -d '"' | tr -d "'")
  desc_len=${#desc}
  if [ "$desc_len" -gt 1024 ]; then
    echo "  ERROR: description is $desc_len chars (max: 1024)"
    errors=$((errors + 1))
  fi

  if [ "$desc_len" -lt 20 ]; then
    echo "  ERROR: description is too short ($desc_len chars). Must clearly state what the skill does AND when to use it."
    errors=$((errors + 1))
  fi

  echo "  OK ($line_count lines)"

done <<< "$skill_files"

if [ "$errors" -gt 0 ]; then
  echo ""
  echo "FAILED: $errors error(s) found"
  exit 1
fi

echo ""
echo "All skill files pass structural checks"
