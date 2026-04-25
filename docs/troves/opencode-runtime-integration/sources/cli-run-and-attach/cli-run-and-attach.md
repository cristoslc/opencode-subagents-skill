---
source-id: cli-run-and-attach
title: "opencode CLI: run, serve, attach — flags, stdin, exit semantics"
type: docs+source
fetched: 2026-04-25
verified: false
notes: "Consolidated from official docs and source. Snapshot gate not run — sources are URL-cited only."
---

# opencode CLI — `run`, `serve`, `attach`

## `opencode run` — headless / non-interactive entry point

Authoritative reference: <https://opencode.ai/docs/cli/> and <https://github.com/sst/opencode/blob/dev/packages/opencode/src/cli/cmd/run.ts>.

| Flag | Short | Purpose |
|------|-------|---------|
| `message` | positional | Prompt; space-joined positional args. Stdin is appended when not a TTY. |
| `--command` | | Run a slash command instead of a prompt; `message` becomes args. |
| `--continue` | `-c` | Resume the last session. |
| `--session` | `-s` | Resume a specific session ID. |
| `--fork` | | Fork before continuing (requires `-c` or `-s`). |
| `--share` | | Share the session publicly (`opncd.ai/s/<id>`). |
| `--model` | `-m` | `provider/model` string. |
| `--agent` | | Agent name; **subagent-mode agents are rejected here**. |
| `--format` | | `default` (human) or `json` (raw event stream to stdout). |
| `--file` | `-f` | Attach file(s); array flag, resolves paths, supports directories. |
| `--title` | | Session title (empty = first 50 chars of prompt). |
| `--attach` | | URL of an existing server (e.g., `http://localhost:4096`). |
| `--password` | `-p` | Basic-auth (or `OPENCODE_SERVER_PASSWORD`). |
| `--dir` | | Working directory; on `--attach`, path on the *remote*. |
| `--port` | | Local server port (random if unset). |
| `--variant` | | Model variant (`high`, `max`, `minimal`, etc.). |
| `--thinking` | | Surface reasoning blocks (default off). |
| `--dangerously-skip-permissions` | | Auto-approve any permission not explicitly denied. |

### Stdin convention

```ts
// run.ts
if (!process.stdin.isTTY) message += "\n" + (await Bun.stdin.text())
```

So `echo "prompt" | opencode run -m anthropic/claude-sonnet-4-5` works; the stdin contents are appended to the positional `message`.

### Exit semantics

`opencode run` blocks on an SSE loop and exits when it sees:

```
event.type === "session.status"
  && event.properties.sessionID === sessionID
  && event.properties.status.type === "idle"
```

Errors arrive as `event.type === "session.error"` — **but invalid-model and provider 429 errors are not always surfaced** (issue #8460, #8203). Always wrap with `timeout` in automation.

### Auto-denied permissions in `run` mode

```ts
const rules: Permission.Ruleset = [
  { permission: "question",   action: "deny" },
  { permission: "plan_enter", action: "deny" },
  { permission: "plan_exit",  action: "deny" },
]
```

These three are silently rejected before any user-defined ruleset applies, preventing the most common headless stalls.

## `opencode serve` — HTTP API daemon

Source: <https://github.com/sst/opencode/blob/dev/packages/opencode/src/cli/cmd/serve.ts>. Docs: <https://opencode.ai/docs/server/>.

```
opencode server listening on http://127.0.0.1:4096
```

Defaults: `--port 4096`, `--hostname 127.0.0.1`. Flags via `withNetworkOptions`: `--port`, `--hostname`, `--mdns`, `--cors`. Auth via HTTP Basic; warns to stderr if `OPENCODE_SERVER_PASSWORD` is unset:

> Warning: OPENCODE_SERVER_PASSWORD is not set; server is unsecured.

Process stays up via `await new Promise(() => {})`. One server is bound to one CWD — for multi-project parallelism, run separate servers on separate ports.

## `opencode attach` — TUI to running backend

```
opencode attach <url> [--dir <path>] [--session <id>]
```

Connects an interactive TUI to an already-running server. Multiple clients (terminal + browser) can attach to the same server simultaneously. Closing the TUI does not stop the backend; the operator can re-attach later. This is the canonical **live-steering / human-in-the-loop** mechanism.

### Persistent-server pattern (gist)

<https://gist.github.com/cakriwut/975fe71acce7a6e80f41a5b2aa916092>

Run `opencode web --hostname 0.0.0.0 --port 4096` as a systemd service; `loginctl enable-linger` for post-logout persistence; reach via Tailscale and `opencode attach http://<host>:4096`. The pattern survives terminal disconnects and supports drive-by inspection.

## Sources

- <https://opencode.ai/docs/cli/>
- <https://open-code.ai/en/docs/cli> (mirror)
- <https://github.com/sst/opencode/blob/dev/packages/opencode/src/cli/cmd/run.ts>
- <https://github.com/sst/opencode/blob/dev/packages/opencode/src/cli/cmd/serve.ts>
- <https://opencode.ai/docs/server/>
- <https://gist.github.com/cakriwut/975fe71acce7a6e80f41a5b2aa916092>
- <https://cefboud.com/posts/coding-agents-internals-opencode-deepdive/>
