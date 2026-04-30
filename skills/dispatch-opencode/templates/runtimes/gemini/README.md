# Gemini CLI adapter (untested)

Gemini CLI (`gemini` from `@google/gemini-cli`) supports two integration
mechanisms: **custom commands** (TOML) and **agent skills** (SKILL.md).
The dispatch-opencode skill supports both.

## Custom command (recommended)

Copy `oc-dispatch.toml` (next to this README) to
`.gemini/commands/oc-dispatch.toml` in the consumer project. The
operator then invokes:

- `/oc-dispatch single-file-fix src/foo.py prompt.md`
- `/oc-dispatch parallel-review-fanout "src/a.py,src/b.py" docs/shared-decisions.md prompt.md`
- `/oc-dispatch headless-spike reports/spike.md prompt.md`

After dispatch, the command surfaces the attach URL so the operator can
drop into the live session.

## Direct invocation

In a Gemini session, ask the agent to run:

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

## Suggested rules entry

Add a rule to your project's `.gemini/settings.json` (or whichever rules
file your install uses) directing the agent toward this skill when a
subagent task is requested:

```json
{
  "rules": [
    {
      "when": "user asks for a focused single-file edit through opencode",
      "do": "Run the bash tool with skills/dispatch-opencode/bin/dispatch-opencode --kind single-file-fix --mode acp --cwd $REPO_ROOT --branch $(git branch --show-current) --target-file <path> --prompt-file <path>. Surface the printed `opencode attach <url> --session <id>` line so the user can attach to the live session."
    }
  ]
}
```

## Status

Untested against a running Gemini CLI install. The TOML command format
and settings.json schema may differ by version; treat the snippets above
as illustrative and adjust to match your install. File issues at
`cristoslc/dispatch-opencode-skill` to record what works.
