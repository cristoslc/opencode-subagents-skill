---
source-id: http-api-and-sdks
title: "opencode HTTP API and language SDKs (JS/TS, Go, Python)"
type: docs+source
fetched: 2026-04-25
verified: false
---

# HTTP API and SDKs

## HTTP API surface

Authoritative: <https://opencode.ai/docs/server/>. Architecture: Hono on Bun, single-port, OpenAPI 3.1 spec at `GET /doc`.

Headline endpoints:

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/session` | Create. Body: `{ parentID?, title? }`. |
| `GET` | `/session/:id` | Read. |
| `DELETE` | `/session/:id` | Delete. |
| `POST` | `/session/:id/message` | **Blocking prompt.** Body: `{ messageID?, model?, agent?, noReply?, system?, tools?, parts }`. |
| `POST` | `/session/:id/prompt_async` | Async prompt; returns 204; progress via SSE. |
| `POST` | `/session/:id/fork` | Fork from a message. |
| `POST` | `/session/:id/diff` | File diff for a session/message. |
| `GET` | `/session/:id/message` | List messages, paginated. |
| `POST` | `/session/:id/command` | Run a slash command. |
| `POST` | `/session/:id/shell` | Execute a shell command in session context. |
| `GET` | `/event` | **SSE stream** of events for the bound CWD. |
| `GET` | `/global/event` | SSE stream across all sessions on the server. |
| `GET` | `/config`, `PATCH /config` | Live config. |
| `GET` | `/config/providers` | Provider list. |
| `GET` `POST` | `/mcp` | MCP server status. |
| `POST` | `/tui/append-prompt`, `/tui/submit-prompt`, `/tui/clear-prompt`, `/tui/execute-command`, `/tui/show-toast` | **Remote-control attached TUI.** |
| `GET` | `/tui/control/next`, `POST /tui/control/response` | Bidirectional TUI control channel. |

The `tui/*` endpoints are how a programmatic dispatcher can inject prompts into a running session that an operator is also viewing in the TUI — the live-steering primitive.

## Event types on the bus

Observed in source and issue threads:

- `server.connected` — first event on SSE connect.
- `session.status` — status transitions (`idle` is the run-loop exit signal).
- `session.idle`, `session.compacted`, `session.diff`.
- `session.error` — transport/provider errors (incomplete coverage).
- `message.part.delta` — token-streaming chunks.
- `permission.asked`, `question.asked` — interactive blocks.

## JS/TS SDK — `@opencode-ai/sdk`

Docs: <https://opencode.ai/docs/sdk/>.

```ts
// In-process server + client
import { createOpencode } from "@opencode-ai/sdk"
const { client } = await createOpencode({ port: 4096, config: {/* ... */} })

// Client only (existing server)
import { createOpencodeClient } from "@opencode-ai/sdk"
const client = createOpencodeClient({ baseUrl: "http://127.0.0.1:4096" })

// Prompt
const session = await client.session.create({ body: {} })
const result = await client.session.prompt({
  path: { id: session.data.id },
  body: {
    parts: [{ type: "text", text: "hello" }],
    model: { providerID: "anthropic", modelID: "claude-sonnet-4-5" },
  },
})

// Structured output
await client.session.prompt({
  path: { id: session.data.id },
  body: {
    parts: [{ type: "text", text: "List three tools." }],
    format: { type: "json_schema", schema: { /* ... */ }, retryCount: 2 },
  },
})
// → result.data.info.structured_output

// SSE
const events = await client.event.subscribe()
for await (const ev of events.stream) { /* ... */ }
```

Internally the CLI's `run` command uses the same SDK against an in-process server (no network hop): `import { createOpencodeClient } from "@opencode-ai/sdk/v2"`.

## Go SDK — `github.com/sst/opencode-sdk-go`

<https://pkg.go.dev/github.com/sst/opencode-sdk-go>. Stainless-generated. Service groups: `Session`, `Agent`, `Command`, `Config`, `Event`, `File`, `Find`, `Path`, `Project`, `App`, `Tui`. Params use `Field[T]` wrapper (`opencode.F(value)`). SSE: `client.Event.ListStreaming()`.

## Python SDK — `opencode-sdk` (anomalyco)

<https://github.com/anomalyco/opencode-sdk-python>. `pip install opencode-sdk` — note: package name is `opencode-sdk`, not `opencode-sdk-python`. Sync (`Opencode`) and async (`AsyncOpencode`) clients; httpx-backed; Stainless-generated.

## Sources

- <https://opencode.ai/docs/server/>
- <https://opencode.ai/docs/sdk/>
- <https://pkg.go.dev/github.com/sst/opencode-sdk-go>
- <https://github.com/anomalyco/opencode-sdk-python>
- <https://www.webdong.dev/en/shortpost/opencode-server/>
- <https://cefboud.com/posts/coding-agents-internals-opencode-deepdive/>
