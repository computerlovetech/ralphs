---
timeout: 30
enabled: true
---
Fix the structural issues in the SKILL.md file. Ensure:
- YAML frontmatter is present with `name` and `description` fields
- The `name` field matches the directory name, is lowercase alphanumeric + hyphens only
- The `description` is between 20 and 1024 characters and clearly states what the skill does AND when to use it
- The file is under 500 lines — move detailed content to reference files if needed
