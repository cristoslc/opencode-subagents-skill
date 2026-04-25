---
source-id: acp-and-mcp
title: "opencode as ACP agent; opencode as MCP client"
type: docs+source
fetched: 2026-04-25
verified: false
---

# ACP (Agent Client Protocol) and MCP

## ACP — `opencode acp`

Docs: <https://opencode.ai/docs/acp/>. Source: <https://github.com/sst/opencode/blob/dev/packages/opencode/src/cli/cmd/acp.ts> and <https://github.com/sst/opencode/blob/dev/packages/opencode/src/acp/agent.ts>.

opencode is the **agent side** of ACP, not the client side. `opencode acp` launches as a subprocess that speaks JSON-RPC over stdio (`ndJsonStream` from `@agentclientprotocol/sdk`). Internally it boots a local opencode server and creates an SDK client to it; ACP messages are translated into SDK calls.

### Launch from the editor

Zed `settings.json`:

```json
{
  "agent_servers": {
    "opencode": {
      "command": "opencode",
      "args": ["acp"]
    }
  }
}
```

JetBrains 2025.3+, Avante.nvim, and CodeCompanion.nvim are also documented as supported clients.

### Implemented ACP methods

From `agent.ts`:

- `initialize` — capabilities, auth method description, version. Reads `clientCapabilities._meta["terminal-auth"]` for terminal-auth.
- `newSession` → `sdk.session.create()`; returns `{ sessionId, configOptions, models }`.
- `loadSession` → loads existing session, replays history.
- `listSessions` → cursor-paginated by timestamp.
- `setSessionModel` → mid-session model swap.
- `prompt` → maps ACP `PromptRequest` parts (`text`, `file`, `code`) to opencode `session.prompt` parts.
- Permission flow: subscribes to `permission.asked`, calls `connection.requestPermission()` with `allow_once | allow_always | reject`.

### Limitations

`/undo` and `/redo` slash commands are not supported over ACP.

### When to choose ACP vs HTTP

ACP's value is the editor-integration contract: stdio JSON-RPC, schema-validated, permission-relay built in. It is a worse fit for headless subagent dispatch — there is no real benefit over HTTP+SSE for that case, and ACP requires the parent to speak the protocol.

## MCP — opencode is a client only

Docs: <https://opencode.ai/docs/cli/> (mcp subcommands) and <https://opencode.ai/docs/mcp-servers/>.

```
opencode mcp add <name>
opencode mcp list
opencode mcp auth [name]
opencode mcp debug <name>
```

opencode **consumes** MCP servers (local stdio or remote HTTP/SSE) — it does not expose itself as one. Status is reachable via `GET /mcp` on the HTTP API. There is no documented or planned mode where opencode itself answers MCP `tools/list` and `tools/call` to a parent.

This means a host CLI that wants to dispatch through opencode cannot do so over MCP today. The dispatch transport choices are:

1. CLI (`opencode run` or `opencode run --attach`).
2. HTTP API (`opencode serve` + REST + SSE).
3. SDK (in-process via `createOpencode`, or remote via `createOpencodeClient`).
4. ACP (only useful when the host is an ACP editor).

## Sources

- <https://opencode.ai/docs/acp/>
- <https://github.com/sst/opencode/blob/dev/packages/opencode/src/cli/cmd/acp.ts>
- <https://github.com/sst/opencode/blob/dev/packages/opencode/src/acp/agent.ts>
- <https://agentclientprotocol.com/get-started/introduction>
- <https://opencode.ai/docs/cli/>
