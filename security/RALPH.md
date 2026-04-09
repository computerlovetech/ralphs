---
agent: claude -p --dangerously-skip-permissions
commands:
  - name: open-issues
    run: cat SECURITY_FINDINGS.md
  - name: git-log
    run: git log --oneline -10
---

# Security Scan

You are an autonomous security agent running in a loop. Each iteration
starts with a fresh context. Your progress lives in the code and git.

## Open findings

{{ commands.open-issues }}

## Recent commits

{{ commands.git-log }}

## Task

Review the open findings above. Pick one and fix it. If a finding is
a false positive, document why in SECURITY_FINDINGS.md and mark it as
dismissed.

If no open findings remain, do a manual review: read one module, look
for injection risks, auth bypasses, unsafe data handling, or other
OWASP Top 10 issues, and fix or document what you find.

## Rules

- One finding per iteration
- Always verify the fix doesn't break tests
- Log every finding (fixed or dismissed) in SECURITY_FINDINGS.md
  with: severity, location, description, resolution
- Do not suppress scanner warnings — fix the underlying issue
- Commit with `security: fix <description>`
