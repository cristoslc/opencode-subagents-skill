---
name: opencode-dispatch
description: >
  Dispatch a subagent task through opencode (https://opencode.ai) instead of the
  host CLI's built-in subagent runtime. Use when the operator wants broader model
  choice (open-weight via Ollama Cloud, OpenRouter, etc.), wants to attach to and
  steer the live subagent session, or needs auditable on-disk dispatch artifacts.
  TRIGGER when: the parent agent would otherwise spawn a built-in subagent and
  the operator has indicated opencode is the preferred backend, or when the task
  benefits from a model the host doesn't natively support, or when parallel
  fanout with per-task isolation is required.
version: 0.1.0
status: draft
---

# opencode-dispatch

Routes subagent dispatch through opencode. The skill owns CWD selection,
template rendering, dispatch execution, and post-run validation. The host
parent does not call opencode directly.

This is v1 — a single neutral entrypoint that all host runtimes invoke the
same way. Future composition along **runtime × model × agent-type** axes will
layer on top without changing the entrypoint.

## When to use

- The operator has asked for an open-weight model (Kimi K2, GLM, Qwen, Llama)
  the host doesn't natively support.
- The operator wants to attach to a running subagent for live inspection or
  manual steering.
- The task fans out across N independent files or repos and needs per-task
  isolation (worktree-per-task).
- The operator wants the dispatch artifact (prompt, files, model, env) on
  disk for replay or audit.

If none of the above apply, prefer the host CLI's built-in subagent runtime —
this skill adds latency and a process boundary.

## When NOT to use

- Editor-integrated agent flows (Zed, JetBrains). Use opencode's ACP support
  directly there — `opencode acp` is the right tool for that case, not this
  skill.
- One-shot prompts where cold-start cost dominates. `opencode run` boots the
  full server per call; for sub-second dispatch needs, that's the wrong shape.

## Three design constraints (non-negotiable)

These are baked into every flow below.

1. **The skill owns the working directory.** Host runtimes differ in their
   ability to shift CWD mid-session — Claude Code can; Codex and Gemini are
   not assumed to. Every dispatch takes an explicit absolute path; the skill
   verifies the path exists, is a git work tree, and matches an expected
   branch or worktree label. **Verification fails closed** — no defaults, no
   inference.

2. **Handoffs are on-disk scripts, not inline tool calls.** Each dispatch
   renders a standalone script (prompt, files, model, agent, cwd, env) under
   `.opencode-dispatch/<task-id>/` from a j2 template, then execs it. The
   rendered script is the source of truth — replays, audits, and manual
   re-runs all read from it.

3. **One template per dispatch *kind*.** Templates are typed by what the
   dispatch is *for* (e.g., `single-file-fix`, `parallel-review-fanout`,
   `headless-spike`), not parameterized into a single megatemplate.

## Dispatch flow

1. **Parse intent** — kind, model, agent, target file(s), prompt body, CWD.
2. **Resolve CWD** — absolute path, must be a git work tree. If the operator
   gave a worktree label or branch name, resolve to a path; if both are
   given, both must agree.
3. **Verify CWD** — call `scripts/verify-cwd.sh <path> [--branch <name>]
   [--worktree <label>]`. Exit non-zero aborts the dispatch.
4. **Allocate task ID** — `<UTC-timestamp>-<short-hash-of-prompt>`. Create
   `.opencode-dispatch/<task-id>/`.
5. **Render** — pick the template by kind. Render to
   `.opencode-dispatch/<task-id>/dispatch.sh`. Also write `prompt.md`,
   `files.txt`, and `env` as separate artifacts (the script reads them).
6. **Pre-flight log** — print the resolved CWD, model, agent, prompt-hash,
   share URL preference, and task-dir path. The operator should be able to
   `cd` to the task dir and re-run `bash dispatch.sh` with no other state.
7. **Execute** — `bash .opencode-dispatch/<task-id>/dispatch.sh`. The
   rendered script wraps `opencode run` in `timeout` and writes three
   artifacts inside the task directory: `events.jsonl` (the JSON event
   stream, via `tee`), `stdout.log` (final stdout), and `stderr.log`
   (opencode stderr). The exit code reflects `opencode`/`timeout`, not
   `tee`.
8. **Post-run validate** — call `scripts/validate-run.sh <task-dir>`.
   Today's checks: `events.jsonl` ends at `session.status: idle` (parsed
   via `jq`, against the real nested-JSON event shape); no
   `session.error` events present; `</think>` blocks stripped from
   `stdout.log` and `events.jsonl` (reasoning-model leakage). The
   frontmatter-drift guard listed below is planned, not yet implemented.
9. **Surface live-steering URL** — if the operator's opencode config has
   `share: auto`, parse the `opncd.ai/s/<id>` URL from `events.jsonl`
   and print it. In serve mode, print
   `opencode attach <server-url> --session <id>` instead. Either way the
   operator can drop into the running session.
10. **Return result** — exit code, task-dir path, hash of edited files,
    stdout summary. The host parent treats this as the subagent's output.

## Default failure-mode mitigations

These are baked into every rendered script. Do not disable without reading
the linked issues in the trove.

- `timeout <SLA>` wraps `opencode run`. Stalls do not block forever.
- `OPENCODE_DISABLE_AUTOCOMPACT=true` — avoids silent exit on compaction
  overflow (issue #13946).
- `OPENCODE_DISABLE_AUTOUPDATE=true` — keeps unattended runs deterministic.
- `--dangerously-skip-permissions` is set per dispatch. **Do NOT pair it
  with `permission: { "*": "allow" }`** — that combination removes every
  guardrail against prompt injection embedded in target-file content
  (code comments, doc strings, PR diffs flow into the model context).
  Instead, ship a per-kind minimal allowlist in opencode config:
    - `single-file-fix` — read access on the repo, write access only on
      the configured `target_file` path.
    - `parallel-review-fanout` (planned) — read on the repo, write only
      on each fanned-out target.
    - `headless-spike` (planned) — read-only; the `explore` agent's
      built-in profile already enforces this.
  Track issue #16367 and remove `--dangerously-skip-permissions` once
  the upstream `serve+attach` permission relay is fixed.
- Post-run `</think>` strip on captured logs.
- Frontmatter diff guard on protected files; auto-revert on drift.
- For Kimi K2 specifically: route via `@ai-sdk/openai-compatible` rather than
  the built-in `openrouter` provider (see issue #1329 thread).

## Configuration

The host parent passes config inline; the skill resolves defaults from
`.opencode-dispatch/config.yaml` at the consumer-repo root.

```yaml
# .opencode-dispatch/config.yaml — example
default_model: ollama-cloud/glm-5.1
default_agent: build
default_timeout_sec: 600
default_share: auto              # or 'manual', 'disabled'
serve:
  enabled: false                 # true → reuse a long-lived `opencode serve`
  url: http://127.0.0.1:4096
  password_env: OPENCODE_SERVER_PASSWORD
worktree_root: .worktrees        # where verify-cwd.sh expects worktree paths
protected_frontmatter_keys:
  - last-updated
templates_dir: skills/opencode-dispatch/templates
```

## Dispatch kinds (templates)

Each kind has its own template under `templates/<kind>.sh.j2`. v1 ships:

| Kind | Use for |
|------|---------|
| `single-file-fix` | One agent edits one file from a focused prompt. |
| `parallel-review-fanout` | N agents, N files, shared decisions doc. (Validated pattern from research-keeper INITIATIVE-003 retro.) |
| `headless-spike` | Read-only investigation; agent writes a report file but does not edit source. |

Add a kind by:

1. Drop a `.sh.j2` template in `templates/`.
2. Add a row to the table above.
3. Add an example invocation to `references/examples.md`.

Don't subclass templates or add j2 inheritance for v1. Copy-paste between
templates is preferred over premature abstraction.

## Composition (v2+, not implemented)

The plan is to layer feature axes on the v1 entrypoint without changing the
flow above:

- **Runtime axis** — per-host shims (`claude-code`, `codex`, `gemini`,
  `cursor`) that translate the host's tool-call shape into this skill's
  `dispatch <kind> <cwd> ...` invocation. Lives under
  `templates/runtimes/<host>.j2`.
- **Model axis** — per-provider overrides (timeout, retry, structured-output
  shape, prompt-shape adjustments). Lives under
  `templates/models/<provider>/<model>.j2`.
- **Agent-type axis** — already covered by the `templates/<kind>.sh.j2`
  layer.

A v2 dispatch resolves all three axes and merges them deterministically. v1
ignores the runtime and model axes and uses a single CLI invocation shape.

Don't pre-build the composition layer. Wait for the second concrete need
(second host runtime; second model with non-trivial overrides) before
generalizing.

## Two-mode execution

Both modes obey the same flow above. The difference is at step 7.

**Mode A — `opencode run` per task** (default).

```
opencode run \
  --dir <verified-cwd> \
  --model <provider/model> \
  --agent <agent> \
  --format json \
  --dangerously-skip-permissions \
  -f <file1> -f <file2> \
  < prompt.md
```

stdin pipe carries the prompt; positional `--file` flags carry the file
list. JSON event stream goes to stdout; the validator parses it.

**Mode B — `opencode serve` + REST** (opt-in via config).

```
curl -u opencode:$OPENCODE_SERVER_PASSWORD \
  http://127.0.0.1:4096/session/<id>/message \
  -d @body.json
```

Body shape per `opencode/docs/server`. SSE events at `/event`. The skill
spawns and re-uses one server per worktree; sessions are tagged with the
task-id.

Mode B amortizes startup. Use it when dispatching > ~5 tasks against the
same worktree in a session.

## What this skill does NOT do

- Spawn opencode in editor / ACP mode.
- Expose opencode via MCP.
- Manage opencode authentication (run `opencode auth login` separately).
- Provision worktrees. The operator (or another skill — `swain-do`'s
  worktree preamble in swain projects) is responsible for creating the
  worktree before dispatch.
- Coordinate between parallel agents beyond per-task isolation. If the
  agents need to converge on cross-cutting decisions (filename conventions,
  schema choices), use a shared-decisions doc convention as a separate
  artifact and pass it into each agent's prompt.

## References

- Trove: `opencode-runtime-integration@4d62897` —
  `docs/troves/opencode-runtime-integration/synthesis.md` and source files.
- Field evidence:
  `~/Documents/code/research-keeper/docs/swain-retro/2026-04-25-multi-round-design-iteration.md`
  (4-agent parallel `opencode run` pattern, validated over 9 rounds and
  36 agent-rounds with zero merge conflicts).
- Failure-mode source list: `references/failure-modes.md` (mirror of trove's
  `failure-modes` source for in-skill reference).
- Examples: `references/examples.md`.
