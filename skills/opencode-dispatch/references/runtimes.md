# Runtime adapters

Per-host integration notes for invoking `bin/opencode-dispatch` from
common agentic CLIs. The skill is **runtime-neutral** — the binary
takes the same arguments regardless of which host calls it. Adapters
are thin shims: a slash command, a rules entry, or a config snippet
that hands the right args to the dispatch binary.

## Status matrix

| Host | Tested | Adapter |
|------|--------|---------|
| Claude Code | yes (this repo) | `templates/runtimes/claude-code/oc-dispatch.md` — copy to `.claude/commands/oc-dispatch.md` |
| Codex CLI | no | `templates/runtimes/codex/README.md` — illustrative shell + toml snippets |
| Gemini CLI | no | `templates/runtimes/gemini/README.md` — illustrative shell + rules snippet |
| Cursor (agent mode) | no | `templates/runtimes/cursor/README.md` — illustrative rules snippet |

Adapters marked "no" have **not** been validated against a real install
of that host. Consumers should expect the schema/format to differ from
what's documented and adjust. File issues at
`cristoslc/opencode-subagents-skill` once a confirmed-working snippet
is found, and the README will be updated.

## Why no host-specific shim is required

The dispatch binary speaks plain command-line arguments and prints to
stdout/stderr. Any host with a "run a shell command" tool can invoke
it. The "adapters" exist purely to capture the operator's preferred
invocation surface in each host:

- Claude Code: a slash command (`/oc-dispatch …`).
- Codex: a named task in `codex.toml`.
- Gemini: a rules entry pointing the agent at the binary.
- Cursor: a rules file in `.cursor/rules/`.

For all four, the underlying call is identical:

```sh
"$REPO_ROOT/skills/opencode-dispatch/bin/opencode-dispatch" \
  --kind <single-file-fix|parallel-review-fanout|headless-spike> \
  --mode <acp|cli|http> \
  --cwd "$REPO_ROOT" \
  --branch "$(git -C "$REPO_ROOT" branch --show-current)" \
  ...
```

## When to write a custom adapter

Skip the templates here and write your own when:

- The host requires a non-shell entry point (e.g., MCP tool, browser
  extension protocol). Wrap the binary in the appropriate transport.
- The operator wants a richer UX than a single command (e.g., a
  picker over kinds, autocomplete on target files). Build that on top.
- Your install differs enough from the templates that copying them
  would mislead. Start fresh and link back here as inspiration.

## Future: composition along feature axes

The SKILL.md "Composition (v2+)" section describes a planned
runtime × model × agent-type axis. The current per-host adapters are
the runtime axis at v1: one shim per host, no composition with model
or agent-type yet. When v2 lands, the adapters will be parameterized
templates rather than hand-rolled snippets.
