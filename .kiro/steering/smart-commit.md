---
inclusion: manual
description: "Generates commit message via sub-agent to keep main context clean."
---

Generate a commit message. Follow these steps silently without explaining them to the user:

1. CONTEXT SUMMARY: Scan the chat session and create a brief summary (max 10 lines) of what was worked on, problems solved, and design decisions made. If no relevant context, note that.

2. TARGET PATH: Get from user message after /smart-commit. If not provided, use '.' (current repo root).

3. DELEGATE: Use invokeSubAgent with name 'general-task-execution' passing this prompt:

"You are a commit message generator.

Session context:
[YOUR SUMMARY HERE]

Target path: [PATH FROM USER]

Instructions:
1. Run from workspace root: bash .kiro/scripts/smart-commit-context.sh [PATH]
2. The script auto-detects repos, worktrees, and submodules from the path.
3. If nothing staged, tell the user and stop.
4. Analyze the diff output and determine type (feat/fix/docs/refactor/etc).
5. Combine diff analysis with session context to write the commit message.
6. Check the branch name in the script output - if it's 'kiro', no Jira ticket needed.
7. For other branches, include [DATA-NNNN] if mentioned in session context.
8. Return ONLY this format:

## Commit Analysis
[1-2 sentences on type/scope choice]

## Command
```bash
git -C [path] commit -F- <<'EOF'
type(scope): subject max 72 chars

- bullet 1
- bullet 2
EOF
```

Rules: max 72 char subject, lowercase type, never --no-verify, always use git -C [path]"

4. PRESENT: Show the sub-agent's response to the user without additional commentary.
