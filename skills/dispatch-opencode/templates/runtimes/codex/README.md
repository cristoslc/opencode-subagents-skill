# Codex CLI adapter (untested)

Codex CLI (`@openai/codex` or `openai-codex`) discovers skills via the
Agent Skills standard (SKILL.md). The dispatch-opencode skill ships
`agents/openai.yaml` for Codex App UI metadata and invocation policy.

## Skill invocation

Codex auto-discovers skills in `.agents/skills/`. Once the
dispatch-opencode skill is installed there, the operator can invoke it
with:

```
$dispatch-opencode
```

Or Codex will auto-select it when the task matches the skill's
description and the operator explicitly invokes `$dispatch-opencode`.

## Direct invocation

In a Codex session, the operator can ask Codex to run the bash tool with:

```sh
REPO_ROOT="$(git rev-parse --show-toplevel)"
"$REPO_ROOT/skills/dispatch-opencode/bin/dispatch-opencode" \
  --kind single-file-fix \
  --mode acp \
  --cwd "$REPO_ROOT" \
  --branch "$(git -C "$REPO_ROOT" branch --show-current)" \
  --target-file <path> \
  --prompt-file <path>
```

## agents/openai.yaml

The skill ships an `agents/openai.yaml` file that provides Codex App
metadata (display name, short description, default prompt) and an
invocation policy (implicit invocation disabled — operator must
explicitly invoke the skill). This file is optional — the skill works
without it in plain Codex CLI — but it improves the UX in the Codex App.

## Status

This adapter has not been validated against a running Codex install.
Consumers should treat the snippets above as a starting point and adjust
to match the Codex version and config schema in their environment.
File issues at `cristoslc/dispatch-opencode-skill` if you confirm the
shape; the README will be updated when a real Codex run is recorded.
