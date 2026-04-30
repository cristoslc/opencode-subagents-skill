# dispatch-opencode

A skill that lets agentic CLIs — Claude Code, Codex, Gemini, and others — dispatch subagent tasks through [opencode](https://opencode.ai) instead of their built-in subagent runtimes.

## Why

Built-in subagent systems are tied to a single model provider and execution surface. Routing through opencode unlocks:

- **Broader model choice.** Dispatch tasks to any model opencode supports — open-weight (Ollama Cloud, OpenRouter) or proprietary — mixing providers per subagent.
- **Live attach.** Each subagent runs in an opencode session you can attach to from another terminal, observe, and steer mid-flight.
- **Auditable artifacts.** Every dispatch writes its prompt, parts, and event stream to `.dispatch-opencode/<task-id>/` for replay or audit.
- **Per-kind permission gating.** The skill's allowlist auto-approves safe tool calls (read, search, file-scoped edits) and rejects everything else — no `--dangerously-skip-permissions`.

## How it works

The skill drives opencode over **ACP (Agent Client Protocol)** on a fixed HTTP port. The host CLI (or its skill adapter) invokes `bin/dispatch-opencode` with a kind, a target, and a prompt file. The binary:

1. Verifies the working directory and branch.
2. Allocates a task directory under `.dispatch-opencode/<task-id>/`.
3. Renders the prompt from a per-kind Jinja2 template.
4. Spawns `opencode acp --port <fixed-port>`, initializes a session, and sends the prompt.
5. Relays permission asks through a per-kind allowlist (rejects by default).
6. Prints the attach URL so you can `opencode attach <url> --session <id>` from another terminal.

Alternate modes (`--mode cli`, `--mode http`) are available when ACP doesn't fit.

## Dispatch kinds

| Kind | Use for | Key flags |
|------|---------|-----------|
| `single-file-fix` | One agent edits one file from a focused prompt | `--target-file`, `--prompt-file` |
| `parallel-review-fanout` | N agents, N files, shared decisions doc | `--target-files`, `--shared-decisions`, `--prompt-file` |
| `headless-spike` | Read-only investigation, agent writes a report file | `--report-path`, `--prompt-file` |

Each kind has its own permission allowlist. `single-file-fix` only allows edits to `--target-file`. `headless-spike` allows read-only bash commands and edits only to `--report-path`. Everything else is denied.

## Install

1. Copy (or symlink) `skills/dispatch-opencode/` into your project's skill directory:
   - Claude Code: `.claude/skills/dispatch-opencode/`
   - Codex: `.agents/skills/dispatch-opencode/`
   - Gemini: `.agents/skills/dispatch-opencode/`
2. Copy the runtime adapter for your host:
   - Claude Code: `templates/runtimes/claude-code/oc-dispatch.md` → `.claude/commands/oc-dispatch.md`
   - Codex: `agents/openai.yaml` is auto-discovered from `.agents/skills/`
   - Gemini: `templates/runtimes/gemini/oc-dispatch.toml` → `.gemini/commands/oc-dispatch.toml`
3. Ensure [opencode](https://opencode.ai), git, Python 3.11+, and [uv](https://docs.astral.sh/uv/) are on PATH.

## Quick examples

```sh
# single-file-fix via ACP
dispatch-opencode \
  --kind single-file-fix --mode acp \
  --cwd "$(git rev-parse --show-toplevel)" \
  --branch "$(git branch --show-current)" \
  --target-file src/calc.py \
  --prompt-file prompt.md

# headless-spike
dispatch-opencode \
  --kind headless-spike --mode acp \
  --cwd "$(git rev-parse --show-toplevel)" \
  --branch "$(git branch --show-current)" \
  --report-path reports/spike.md \
  --prompt-file prompt.md
```

## Runtime adapters

| Host | Status | Adapter |
|------|--------|---------|
| Claude Code | tested | `.claude/commands/oc-dispatch.md` |
| Codex CLI | untested | `agents/openai.yaml` + direct invocation |
| Gemini CLI | untested | `.gemini/commands/oc-dispatch.toml` |
| Cursor | untested | `.cursor/rules/` snippet |

See `skills/dispatch-opencode/references/runtimes.md` and `skills/dispatch-opencode/templates/runtimes/` for details.

## Configuration

Defaults live in `.dispatch-opencode/config.yaml` at the repo root:

```yaml
mode: acp
acp:
  port: 4096
  hostname: "127.0.0.1"
default_model: ollama-cloud/glm-5.1
default_agent: build
default_timeout_sec: 600
worktree_root: .worktrees
templates_dir: skills/dispatch-opencode/templates   # adjust if installed elsewhere
```

## Documentation

- `skills/dispatch-opencode/SKILL.md` — full design contract, dispatch flow, permission model
- `skills/dispatch-opencode/references/examples.md` — invocation examples per kind and mode
- `skills/dispatch-opencode/references/runtimes.md` — per-host adapter status and wiring

## License

MIT
