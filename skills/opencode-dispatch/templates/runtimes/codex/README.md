# Codex CLI adapter (untested)

Codex CLI (`@openai/codex` or `openai-codex`) supports custom commands and
shell escapes. The opencode-dispatch skill works with Codex via a shell
escape inside Codex's prompt — the same `bin/opencode-dispatch` binary,
no runtime-specific shim required.

## Recommended invocation

In a Codex session, the operator can ask Codex to run the bash tool with:

```sh
REPO_ROOT="$(git rev-parse --show-toplevel)"
"$REPO_ROOT/skills/opencode-dispatch/bin/opencode-dispatch" \
  --kind single-file-fix \
  --mode acp \
  --cwd "$REPO_ROOT" \
  --branch "$(git -C "$REPO_ROOT" branch --show-current)" \
  --target-file <path> \
  --prompt-file <path>
```

## Suggested config

If your Codex install supports a `codex.toml` with named tasks, add an
entry that wires the dispatch:

```toml
[[tasks]]
name = "oc-fix"
description = "Dispatch a single-file-fix subagent through opencode"
command = "skills/opencode-dispatch/bin/opencode-dispatch --kind single-file-fix --mode acp --cwd . --branch \"$(git branch --show-current)\" --target-file {{ target }} --prompt-file {{ prompt }}"
args = ["target", "prompt"]
```

## Status

This adapter has not been validated against a running Codex install.
Consumers should treat the snippet above as a starting point and adjust
to match the Codex version and config schema in their environment.
File issues at `cristoslc/opencode-subagents-skill` if you confirm the
shape; the README will be updated when a real Codex run is recorded.
