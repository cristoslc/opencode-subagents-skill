---
name: opencode-dispatch
description: >
  Dispatch a subagent task through opencode (https://opencode.ai) instead of
  the host CLI's built-in subagent runtime. The skill drives opencode over
  ACP (Agent Client Protocol) on a fixed port, so the operator can attach
  to the live session for inspection or manual steering. Use when the
  operator wants broader model choice (open-weight via Ollama Cloud,
  OpenRouter, etc.), wants live attach, or needs auditable on-disk
  dispatch artifacts. TRIGGER when: the parent agent would otherwise
  spawn a built-in subagent and the operator has indicated opencode is
  the preferred backend, or when the task benefits from a model the host
  doesn't natively support, or when parallel fanout with per-task
  isolation is required.
version: 0.2.0
status: draft
---

# opencode-dispatch

Routes subagent dispatch through opencode using **ACP (Agent Client
Protocol) over a fixed HTTP port**. The skill is the ACP client; the
operator can `opencode attach http://<host>:<port>` from another terminal
to see the live session and steer it.

This is the primary mode. CLI `opencode run` and HTTP `opencode serve`
remain as alternates for the cases ACP doesn't fit (see "Alternate
modes" below).

ACP is the right default because it solves four problems at once that
the CLI/HTTP modes only solved partially:

- **Native permission relay.** No `--dangerously-skip-permissions`, no
  wildcard `permission: { '*': 'allow' }` config hack. The host (or
  the skill on its behalf) approves or denies each tool call as
  opencode asks.
- **Zero shell-injection surface.** Prompts and arguments are JSON-RPC
  payloads, not shell strings. No quoting, no template-injection class.
- **Standardized session lifecycle.** `initialize`, `newSession`,
  `prompt`, `setSessionModel`, idle detection — all wire-defined.
- **Live attach via the same internal HTTP server** that ACP boots.
  When the port is fixed, `opencode attach <url>` reaches it like any
  other opencode server.

## When to use

- The operator wants an open-weight model (Kimi K2, GLM, Qwen, Llama)
  the host doesn't natively support.
- The operator wants to attach to a running subagent for live
  inspection or manual steering.
- The task fans out across N independent files or repos and needs
  per-task isolation (worktree-per-task).
- The operator wants the dispatch artifact (prompt parts, files,
  model, agent, cwd) on disk for replay or audit.

If none apply, prefer the host CLI's built-in subagent runtime — this
skill adds a process boundary and a protocol layer.

## When NOT to use

- One-shot prompts where cold-start cost dominates and live attach is
  not needed. Fall back to alternate-mode CLI `opencode run`.
- The host runtime forbids spawning long-lived subprocesses. Fall back
  to alternate-mode CLI `run` per task.

## Three design constraints (non-negotiable)

These hold across all modes.

1. **The skill owns the working directory.** Host runtimes differ in
   their ability to shift CWD mid-session — Claude Code can; Codex and
   Gemini are not assumed to. Every dispatch takes an explicit absolute
   path; the skill verifies the path exists, is a git work tree, and
   matches an expected branch or worktree label. **Verification fails
   closed** — no defaults, no inference. The verified path is passed to
   ACP `newSession` (or `--dir` in CLI mode).

2. **Handoffs are on-disk artifacts.** Every dispatch writes the
   request payload to disk under `.opencode-dispatch/<task-id>/` before
   sending. In ACP mode the artifact is the rendered `prompt` request
   body (`prompt.json`); in CLI mode it is a `dispatch.sh`. Either way
   the task directory is the source of truth for replay and audit.

3. **One template per dispatch *kind*.** Templates are typed by what
   the dispatch is *for* (e.g., `single-file-fix`,
   `parallel-review-fanout`, `headless-spike`), not parameterized into
   a single megatemplate. ACP and CLI mode each have their own per-kind
   template family.

## Required arguments

A host runtime invokes the skill with these named arguments.

| Flag | Required | Type | Description |
|------|----------|------|-------------|
| `--kind` | yes | enum | One of the kinds in the table below. |
| `--cwd` | yes | absolute path | Working directory; must pass `verify-cwd.sh`. |
| `--branch` | no | string | Expected branch name; verified against `git branch --show-current`. |
| `--worktree` | no | label | Expected worktree label; requires `--worktree-root`. |
| `--worktree-root` | conditional | absolute path | Worktree-root prefix; required when `--worktree` is set. |
| `--model` | yes | `provider/model` | opencode model string (e.g. `ollama-cloud/glm-5.1`). |
| `--agent` | yes | string | opencode agent name (`build`, `general`, `explore`, or a project agent). |
| `--target-file` | conditional | path | Required by `single-file-fix`. Path inside `--cwd`. |
| `--prompt-file` | yes | path | Path to a markdown prompt file; rendered into the task dir as `prompt.md`. |
| `--timeout` | no | seconds | Per-dispatch timeout. Defaults to `default_timeout_sec` in `config.yaml`. |
| `--mode` | no | enum | `acp` (default), `cli`, or `http`. |
| `--extra-env` | no | `K=V` (repeatable) | Extra environment for the rendered script. Keys must match `^[A-Za-z_][A-Za-z0-9_]*$`; values are shell-quoted by the renderer. CLI mode only. |

Per-kind required arguments are listed alongside each kind below.

## Dispatch flow (ACP mode, primary)

1. **Parse intent** — kind, model, agent, target file(s), prompt body,
   CWD.
2. **Resolve CWD** — absolute path, must be a git work tree.
3. **Verify CWD** — `scripts/verify-cwd.sh <path> [--branch <name>]
   [--worktree <label> --worktree-root <absolute-root>]`. Exit non-zero
   aborts the dispatch.
4. **Allocate task ID** — `<UTC-timestamp>-<short-hash-of-prompt>`.
   Create `.opencode-dispatch/<task-id>/`.
5. **Render prompt parts** — pick the template by kind from
   `templates/acp/<kind>.prompt.j2`. Render prompt text plus the file
   part list into `.opencode-dispatch/<task-id>/prompt.json` (the ACP
   `prompt` request body). Also write `prompt.md` (the raw prompt
   text) and `parts.json` (the file/text parts that the prompt
   references) for human inspection.
6. **Ensure ACP backend** — connect to or spawn `opencode acp --port
   <fixed-port>` (port read from `config.yaml`). Confirm the embedded
   HTTP server is reachable at `http://<host>:<port>`. Log the URL —
   the operator needs it to attach.
7. **Initialize + newSession** — send ACP `initialize`, then
   `newSession({ cwd: <verified-path>, mcpServers: [], model: <model>,
   agent: <agent> })`. Capture `sessionId`.
8. **Pre-flight log** — print `task-id`, verified CWD, model, agent,
   ACP server URL, session ID, attach command:

   ```
   opencode attach http://127.0.0.1:4096 --session <sessionId>
   ```

9. **Send prompt** — POST the rendered `prompt.json` as the ACP
   `prompt` request. Stream the response events to
   `.opencode-dispatch/<task-id>/events.jsonl` and any text deltas to
   `stdout.log`.
10. **Handle permission asks** — when ACP delivers a `permission.ask`
    request, the skill consults the per-kind allowlist (see "Permission
    model" below) and responds `allow_once` / `allow_always` /
    `reject`. Each decision is logged with reason and rule reference.
11. **Wait for idle** — return when the session reaches the ACP idle
    state, or when `--timeout` elapses.
12. **Post-run validate** — `scripts/validate-run.sh <task-dir>`.
    Checks: `events.jsonl` ends at `session.status: idle`; no
    `session.error` events; `</think>` blocks stripped from
    `stdout.log` and `events.jsonl` (reasoning-model leakage).
13. **Return result** — exit code, task-dir path, session ID,
    attach URL. The host parent treats this as the subagent's output.

## Permission model

ACP delivers each tool-call permission ask to the client. The skill
ships a per-kind allowlist; defaults are conservative.

| Kind | Read | Write | Bash | Task / sub-dispatch |
|------|------|-------|------|---------------------|
| `single-file-fix` | repo | only `--target-file` | deny | deny |
| `parallel-review-fanout` (planned) | repo | only the kind's target list | deny | deny |
| `headless-spike` (planned) | repo | only `--report-path` | `git status *`, `git diff *` allow; rest deny | deny |

Outside the allowlist, the skill rejects. The operator can
override per-task with `--permission-override <rule>` (logged) or via
the attached TUI when answering the permission prompt out-of-band.

## Default failure-mode mitigations

Baked in by the skill's ACP client and rendered artifacts.

- `--timeout <SLA>` enforced by the ACP client. Stalls do not block
  forever.
- `OPENCODE_DISABLE_AUTOCOMPACT=true` set in the spawned `opencode acp`
  process — avoids silent exit on compaction overflow (issue #13946).
- `OPENCODE_DISABLE_AUTOUPDATE=true` set in the same env — keeps
  unattended runs deterministic.
- `OPENCODE_SERVER_PASSWORD` required (refuse to start ACP backend
  without one). The fixed-port server is otherwise unauthenticated.
- Per-kind permission allowlist (see above). No wildcard allow, no
  `--dangerously-skip-permissions`.
- Post-run `</think>` strip on `stdout.log` and `events.jsonl`
  (reasoning-model leakage).
- Frontmatter diff guard on protected files; auto-revert on drift
  (planned, not yet implemented).
- For Kimi K2 specifically: route via `@ai-sdk/openai-compatible`
  rather than the built-in `openrouter` provider (issue #1329).

## Configuration

Defaults live in `.opencode-dispatch/config.yaml` at the consumer-repo
root.

```yaml
# .opencode-dispatch/config.yaml — example
mode: acp                          # acp | cli | http
acp:
  port: 4096                       # fixed; required for live attach
  hostname: 127.0.0.1              # 0.0.0.0 only if you understand mDNS / firewalling
  spawn: true                      # true → skill spawns `opencode acp`; false → expects a running one
  password_env: OPENCODE_SERVER_PASSWORD   # must be set; the skill refuses to start without it
default_model: ollama-cloud/glm-5.1
default_agent: build
default_timeout_sec: 600
worktree_root: .worktrees
protected_frontmatter_keys:
  - last-updated
templates_dir: skills/opencode-dispatch/templates
```

The fixed `acp.port` is what makes ACP mode attachable. Changing it
later breaks any operator-facing attach commands the skill has logged.

## Dispatch kinds

Each available kind has matching templates under
`templates/acp/<kind>.prompt.j2` (and, for the alternate CLI mode,
`templates/cli/<kind>.sh.j2`).

| Kind | Status | Use for |
|------|--------|---------|
| `single-file-fix` | **available** (CLI mode); ACP template planned | One agent edits one file from a focused prompt. Required: `--target-file`. |
| `parallel-review-fanout` | planned (no template, either mode) | N agents, N files, shared decisions doc. Validated pattern from research-keeper INITIATIVE-003 retro. Will require `--target-files` and `--shared-decisions`. |
| `headless-spike` | planned (no template, either mode) | Read-only investigation; agent writes a report file but does not edit source. Will require `--report-path` and use the `explore` agent. |

Selecting a kind whose template is missing for the chosen mode aborts
the dispatch with a clear error.

Add a kind by:

1. Drop a `<kind>.prompt.j2` in `templates/acp/`.
2. Drop a `<kind>.sh.j2` in `templates/cli/` (optional).
3. Add a permission-allowlist row to "Permission model".
4. Add a row to the table above.
5. Add an example invocation to `references/examples.md`.

Don't subclass templates or add j2 inheritance for v1. Copy-paste
between templates beats premature abstraction.

## Composition (v2+, not implemented)

Layers planned on top of the v1 entrypoint without changing the flow:

- **Runtime axis** — per-host shims (`claude-code`, `codex`, `gemini`,
  `cursor`) that translate the host's tool-call shape into this
  skill's invocation. Lives under `templates/runtimes/<host>.j2`.
- **Model axis** — per-provider overrides (timeout, retry,
  structured-output shape, prompt-shape adjustments). Lives under
  `templates/models/<provider>/<model>.j2`.
- **Agent-type axis** — already covered by the kind-template layer.

Don't pre-build composition. Wait for the second concrete need (second
host runtime; second model with non-trivial overrides) before
generalizing.

## Alternate modes

### CLI `run` per task

Selected by `--mode cli`. Best for fire-and-forget where live attach
is not needed. The rendered artifact is a shell script
(`templates/cli/<kind>.sh.j2`) that wraps `opencode run --format json`
in `timeout` and writes `events.jsonl`, `stdout.log`, `stderr.log`.
This is what `single-file-fix.sh.j2` does today.

The CLI invocation shape:

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

`--dangerously-skip-permissions` is required only in CLI mode. In ACP
mode it is forbidden.

### HTTP `serve` + REST

Selected by `--mode http`. Useful when the host runtime cannot speak
ACP (no JSON-RPC stdio support) but a long-lived warm dispatcher is
still wanted. The skill spawns `opencode serve --port <fixed>` and
talks to it over the OpenAPI surface. Live attach works the same way
as in ACP mode.

Pass credentials via `.netrc` rather than `curl -u`:

```
NETRC="$TASK_DIR/.netrc"
umask 077
printf 'machine 127.0.0.1 login opencode password %s\n' \
  "$OPENCODE_SERVER_PASSWORD" > "$NETRC"
curl --netrc-file "$NETRC" \
  http://127.0.0.1:4096/session/<id>/message \
  -d @body.json
```

Body shape per opencode/docs/server. SSE events at `/event`. The skill
reuses one server per worktree; sessions are tagged with the task-id.
HTTP mode does NOT get native permission relay — issue #16367 still
applies.

## What this skill does NOT do

- Run inside an editor as the ACP agent for that editor (Zed,
  JetBrains). Editor flows should call `opencode acp` directly via
  the editor's agent-server config — that is opencode's primary ACP
  use case and this skill is the wrong wrapper for it.
- Expose opencode via MCP. opencode is an MCP client only.
- Manage opencode authentication. Run `opencode auth login`
  separately.
- Provision worktrees. The operator (or another skill — `swain-do`'s
  worktree preamble in swain projects) creates the worktree before
  dispatch.
- Coordinate between parallel agents beyond per-task isolation. If
  agents need to converge on cross-cutting decisions, use a
  shared-decisions doc as a separate artifact and pass it into each
  agent's prompt.

## References

- Trove: `opencode-runtime-integration@4d62897` —
  `docs/troves/opencode-runtime-integration/synthesis.md` and source
  files. Failure-mode catalogue at
  `docs/troves/opencode-runtime-integration/sources/failure-modes/failure-modes.md`.
- ACP source: `packages/opencode/src/cli/cmd/acp.ts` and
  `packages/opencode/src/acp/agent.ts` in github.com/sst/opencode.
- ACP attachability check (this design's foundation): the embedded
  server uses the same `withNetworkOptions` / `Server.listen` path as
  `opencode serve`. Defaults are port `0` (random) and hostname
  `127.0.0.1`; pass an explicit `--port` to make the URL reachable
  from `opencode attach`.
- Field evidence: `~/Documents/code/research-keeper/docs/swain-retro/2026-04-25-multi-round-design-iteration.md`.
- Examples: `references/examples.md`.
