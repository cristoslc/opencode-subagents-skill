---
source-id: agents-sessions-output
title: "opencode agents, sessions, output capture"
type: docs+source
fetched: 2026-04-25
verified: false
---

# Agents, sessions, output capture

## Agent system

Docs: <https://opencode.ai/docs/agents/>. DeepWiki: <https://deepwiki.com/sst/opencode/3.2-agent-system>.

Agents live in `.opencode/agents/<name>.md` (project) or `~/.config/opencode/agents/<name>.md` (global). Frontmatter schema:

```yaml
---
description: "..."
mode: subagent          # primary | subagent | all
model: anthropic/claude-sonnet-4-5
temperature: 0.1
steps: 20
permission:
  edit: deny
  bash: { "*": "ask", "git status *": "allow" }
  task: { "*": "deny", "explore": "allow" }
hidden: true
disable: false
---
System prompt body.
```

Built-in agents:

- `build` — primary, all tools allowed.
- `plan` — primary, all tools `"ask"`.
- `general` — subagent, full tools, `todowrite` denied (so subagents don't pollute the parent's task list).
- `explore` — subagent, read-only (`grep`, `glob`, `list`, `bash`, `read`, `search`).

### Subagent invocation inside a session

The primary agent calls the `task` tool, which creates a child session with `parentID` set, isolated context, possibly a different model. `@mention` in the TUI does the same. Children navigate via `session_child_first` / `session_child_cycle`.

This is the **built-in** subagent mechanism — but it dispatches *inside* a single opencode process. Cross-process orchestration (the use case for this skill) is not built in.

## Sessions on disk

Logs: `~/.local/share/opencode/log/<timestamp>.log`. Last 10 retained. Enable with `--print-logs` or `--log-level DEBUG`.

Session export/import:

```
opencode export <sessionID>          # → JSON to stdout
opencode import <file|share-url>     # accepts opncd.ai/s/<id>
opencode session list [-n N] [--format table|json]
```

Share URLs: `opncd.ai/s/<share-id>`. Modes: `manual` (default), `auto`, `disabled`.

## `--format json` event stream

`opencode run --format json` emits raw JSON events to stdout, one per line. Observed event types:

- `step_start`, `step_finish` — agent step boundaries.
- `text` — assistant text deltas.
- `reasoning` — only when `--thinking` is set.
- `error` — surfaces some but not all errors.

A dispatcher should consume this stream and treat the absence of `session.status: idle` (within a timeout) as a stall.

## Headless permission stalls

Three permissions are auto-denied in `run` mode (see CLI source): `question`, `plan_enter`, `plan_exit`. Beyond that, `--dangerously-skip-permissions` should be set for unattended dispatch. Issue #16367 documents that `opencode serve + opencode attach` does **not** relay `permission: ask` prompts back to the attached TUI in some configurations — set `permission: { "*": "allow" }` in config when running this combo headless.

## Sources

- <https://opencode.ai/docs/agents/>
- <https://deepwiki.com/sst/opencode/3.2-agent-system>
- <https://github.com/sst/opencode/issues/16367>
- <https://github.com/sst/opencode/issues/8460>
- <https://opencode.ai/docs/cli/>
