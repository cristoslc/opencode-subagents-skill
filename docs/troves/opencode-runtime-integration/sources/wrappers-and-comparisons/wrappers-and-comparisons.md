---
source-id: wrappers-and-comparisons
title: "Existing wrappers, parallel-orchestration patterns, and transport comparison"
type: repo+blog+gist
fetched: 2026-04-25
verified: false
---

# Wrappers and comparisons

## awesome-opencode

<https://github.com/awesome-opencode/awesome-opencode>. Curated list. Notable subagent-adjacent projects:

- **Background Agents** — async delegation plugin.
- **Pocket Universe** — closed-loop async agents.
- **Oh My Openagent** (`code-yeongyu/oh-my-openagent`) — agent harness.
- **Swarm Plugin** — swarm coordination.
- **CLI Proxy API** — multi-model proxy gateway.
- **GolemBot** — unified framework wrapping multiple coding CLIs.
- **hcom** — inter-agent messaging across terminals.
- **Baton** (<https://getbaton.dev/agents/opencode>) — GUI multi-session manager that uses git worktree isolation per session.
- **opencode-parallel-agents** (`aptdnfapt/opencode-parallel-agents`).
- **opencode-agent-squad** (`Burgunthy/opencode-agent-squad`).

## Smithery: opencode-cli skill

<https://smithery.ai/skills/SpillwaveSolutions/opencode-cli>. A Claude Code skill that wraps `opencode run` as a dispatch target. Closest existing analogue to this project. Treat as prior art when designing the skill's interface.

## Autonomous multi-agent gist (ppries)

<https://gist.github.com/ppries/f07fd6316bbd45807dd7a1896555b05b>. Production orchestration pattern using `@agent` mention + `task` tool for in-process parallel dispatch. Notable: all coordination happens *inside one opencode TUI session*, not via `opencode run`. The orchestrator runs as `agent: build` for unrestricted tool access; specialized subagents (`@check`, `@simplify`) run in parallel during review phases. This is opencode's *native* parallelism, not the cross-process model this skill targets.

## Parallel patterns in practice

From issue #4251 and Baton: the durable pattern is **one opencode process or server per worktree**, with the parent dispatcher choosing the worktree per task. Worktree isolation gives:

- Separate file state (no cross-task interference).
- Branch-per-task auditability.
- Cheap rollback (delete the worktree).

The recurring failure mode is shared-CWD parallelism: even `opencode serve` (one server, multiple sessions, same CWD) eventually races on file edits.

## Transport comparison

Distilled from the docs and threads above:

| Concern | `opencode run` (one-shot) | `opencode serve` + REST/SDK | ACP (`opencode acp`) |
|---|---|---|---|
| Best for | Cron-style dispatch, single fire-and-forget tasks | Long-lived dispatcher, many tasks against warm sessions | Editor integration only (Zed/JetBrains) |
| Startup cost | Process+model load every call | Pay once, reuse | Process boot per editor session |
| Live steering | Only via `--share` URL viewer | TUI-control endpoints (`/tui/*`) + multi-attach | Editor UI relays permissions and prompts |
| Output format | `--format json` line-stream | SSE + structured JSON | JSON-RPC notifications |
| Permission relay | Auto-deny for `question`/`plan_*`; otherwise `--dangerously-skip-permissions` | Same as `run`; `serve+attach` has known relay bug (#16367) | Built-in relay over JSON-RPC |
| Stall surface | `session.status: idle` via SSE; no idle in many error paths | Same SSE; can poll session state explicitly | JSON-RPC error response |
| Suitability for this skill | Good for stateless dispatch + fixed prompt template | **Best for warm long-running dispatch** | Wrong shape — host CLIs are not ACP clients |

## opencode architecture deep dive (cefboud)

<https://cefboud.com/posts/coding-agents-internals-opencode-deepdive/>. Confirms: opencode is a Bun/Hono server with a Go TUI client; **any HTTP client can drive the agent**; `streamText()` from the AI SDK powers generations; the Event Bus broadcasts to all SSE subscribers; sessions persist as message-part records on disk; auto-compaction at 90% context.

> Any client capable of making HTTP requests can interact with the server and drive the agent.

This is the architectural permission slip for treating opencode as a subagent backend.

## WebDong: deploy server for multiple clients

<https://www.webdong.dev/en/shortpost/opencode-server/>. Confirms multi-client attach, OpenAPI exposure, single-port architecture, and CWD-per-server constraint.

## Sources

- <https://github.com/awesome-opencode/awesome-opencode>
- <https://smithery.ai/skills/SpillwaveSolutions/opencode-cli>
- <https://gist.github.com/ppries/f07fd6316bbd45807dd7a1896555b05b>
- <https://getbaton.dev/agents/opencode>
- <https://github.com/sst/opencode/issues/4251>
- <https://cefboud.com/posts/coding-agents-internals-opencode-deepdive/>
- <https://www.webdong.dev/en/shortpost/opencode-server/>
