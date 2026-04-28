# Cursor agent-mode adapter (untested)

Cursor's agent mode runs shell commands through a terminal tool. The
opencode-dispatch skill works without a Cursor-specific shim — the
operator (or a Cursor rules file) directs the agent to invoke
`bin/opencode-dispatch` directly.

## Recommended invocation

In Cursor's agent mode, the operator can ask:

> Run `skills/opencode-dispatch/bin/opencode-dispatch --kind single-file-fix --mode acp --cwd "$(git rev-parse --show-toplevel)" --branch "$(git branch --show-current)" --target-file <path> --prompt-file <path>` and report back the attach URL.

## Suggested rules

Add a rule to your project's `.cursor/rules/opencode-dispatch.mdc` (or
whichever rules file your Cursor version uses):

```markdown
---
description: Dispatch focused subagent tasks through opencode for broader model choice and live attach.
---

When the user asks for a single-file edit, parallel review fanout, or
read-only investigation that should run through opencode rather than
Cursor's built-in agent:

1. Resolve `$REPO_ROOT` via `git rev-parse --show-toplevel`.
2. Run the terminal tool with the `opencode-dispatch` binary in this
   project (or a wrapper symlinked into `bin/`). See
   `skills/opencode-dispatch/SKILL.md` for the full argument table.
3. Print the `opencode attach <url> --session <id>` line from the
   dispatch output so the user can drop into the live session.
```

## Status

Untested against a running Cursor install. The exact rules-file format
varies by Cursor version; treat the snippet above as illustrative.
