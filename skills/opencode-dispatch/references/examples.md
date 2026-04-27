# Examples

Concrete invocations of `opencode-dispatch`. Update when adding a kind
or a mode.

## single-file-fix — ACP mode (primary, ACP template planned)

> The ACP `prompt`-payload template for this kind is not yet shipped.
> Use CLI mode below until `templates/acp/single-file-fix.prompt.j2`
> lands.

The intended invocation:

<!-- NOT IMPLEMENTED — illustrative only -->
```
opencode-dispatch \
  --kind single-file-fix \
  --mode acp \
  --cwd /Users/cristos/Documents/code/myrepo \
  --branch feature/auth-rewrite \
  --model ollama-cloud/glm-5.1 \
  --agent build \
  --target-file src/auth/middleware.ts \
  --prompt-file prompt.md \
  --timeout 600
```

Will produce, under `.opencode-dispatch/<task-id>/`:

- `prompt.md` — the raw prompt text the operator passed.
- `prompt-parts.json` — the rendered ACP prompt-parts array
  (text + file part).
- `prompt-request.json` — the final wire payload sent to ACP `prompt`.
- `events.jsonl` — streamed ACP events for replay / validation.
- `stdout.log` — text deltas extracted from the event stream.

The pre-flight log will print the attach command, e.g.:

```
opencode attach http://127.0.0.1:4096 --session sess_abc123
```

The operator can drop into that URL from another terminal to inspect
or steer the running session.

## single-file-fix — CLI mode (available)

A focused edit on one file. Backed by `templates/cli/single-file-fix.sh.j2`.

```
opencode-dispatch \
  --kind single-file-fix \
  --mode cli \
  --cwd /Users/cristos/Documents/code/myrepo \
  --branch feature/auth-rewrite \
  --model ollama-cloud/glm-5.1 \
  --agent build \
  --target-file src/auth/middleware.ts \
  --prompt-file prompt.md \
  --timeout 600
```

Renders to `.opencode-dispatch/<task-id>/dispatch.sh`. The operator
can `cd` to that directory and re-run `bash dispatch.sh` for an exact
replay. CLI mode requires `--dangerously-skip-permissions` and a
permission allowlist in opencode config; it does not support live
attach beyond the `--share` URL the model may emit.

## parallel-review-fanout — ACP mode (available)

N independent children, each driven by its own `opencode acp` process
on a distinct port. Each child gets the shared-decisions document
prepended to its prompt and is constrained by the per-kind allowlist
to edit only its own `--target-file`. The pattern is field-validated
in the research-keeper INITIATIVE-003 retro (4 agents, 9 rounds, 0
merge conflicts).

```
opencode-dispatch \
  --kind parallel-review-fanout \
  --mode acp \
  --cwd /Users/cristos/Documents/code/myrepo \
  --branch design-iteration \
  --model ollama-cloud/glm-5.1 \
  --agent build \
  --shared-decisions docs/iter/shared-decisions-v3.md \
  --target-files docs/spec-a.md,docs/spec-b.md,docs/spec-c.md,docs/spec-d.md \
  --timeout 1200 \
  --parallel 4
```

The dispatcher allocates a free port starting from `acp.port` for
each child and prints an `opencode attach <url> --session <id>`
command per child so the operator can attach to any one. Children's
artifacts land under `.opencode-dispatch/<parent-id>/<file-slug>/`;
the parent task dir holds `parent.json` (file → child task-dir
index) and `shared-decisions.md` (a copy of the doc as it was at
dispatch time).

Tips from the field retro:

- Each round of multi-agent iteration should pre-bake every
  cross-cutting choice in `shared-decisions-vN.md`. Don't rely on
  agents to converge independently.
- When iterating, commit between rounds so any agent regression is
  cheap to roll back.
- Below ~50 lines of change in late rounds, manual `Edit` is faster
  than respawning a stalled LLM agent.

## headless-spike — NOT IMPLEMENTED (illustrative only)

> No template ships for this kind in either mode yet. Running it
> returns a missing-template error.

Read-only investigation. The agent writes a report to a known path;
source is not modified.

<!-- NOT IMPLEMENTED — illustrative only -->
```
opencode-dispatch \
  --kind headless-spike \
  --mode acp \
  --cwd /Users/cristos/Documents/code/myrepo \
  --branch main \
  --model anthropic/claude-sonnet-4-5 \
  --agent explore \
  --report-path reports/spike-2026-04-27.md \
  --prompt-file prompt.md \
  --timeout 900
```

The `explore` agent's read-only permission profile, combined with the
skill's `headless-spike` allowlist, will prevent accidental edits.
