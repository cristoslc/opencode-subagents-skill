# Gemini CLI adapter (untested)

Gemini CLI (`gemini` from `@google/gemini-cli`) executes shell commands
through a built-in `run_shell_command` (or equivalent) tool. The
opencode-dispatch skill works without a Gemini-specific shim — the
operator (or agent rules) just invoke `bin/opencode-dispatch` directly.

## Recommended invocation

In a Gemini session, ask the agent to run:

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

## Suggested rules entry

Add a rule to your project's `.gemini/settings.json` (or whichever rules
file your install uses) directing the agent toward this skill when a
subagent task is requested:

```json
{
  "rules": [
    {
      "when": "user asks for a focused single-file edit through opencode",
      "do": "Run the bash tool with skills/opencode-dispatch/bin/opencode-dispatch --kind single-file-fix --mode acp --cwd $REPO_ROOT --branch $(git branch --show-current) --target-file <path> --prompt-file <path>. Surface the printed `opencode attach <url> --session <id>` line so the user can attach to the live session."
    }
  ]
}
```

## Status

Untested against a running Gemini CLI install. The schema for
`.gemini/settings.json` may differ; treat this as illustrative and
adjust to match your version. File issues at
`cristoslc/opencode-subagents-skill` to record what works.
