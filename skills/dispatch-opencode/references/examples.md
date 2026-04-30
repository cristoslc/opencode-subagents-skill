# Examples

Concrete invocations of `dispatch-opencode`. Update when adding a kind
or a mode.

## single-file-fix — ACP mode (primary, ACP template planned)

> The ACP `prompt`-payload template for this kind is not yet shipped.
> Use CLI mode below until `templates/acp/single-file-fix.prompt.j2`
> lands.

The intended invocation:

<!-- NOT IMPLEMENTED — illustrative only -->
```
dispatch-opencode \
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

Will produce, under `.dispatch-opencode/<task-id>/`:

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
dispatch-opencode \
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

Renders to `.dispatch-opencode/<task-id>/dispatch.sh`. The operator
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
dispatch-opencode \
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
artifacts land under `.dispatch-opencode/<parent-id>/<file-slug>/`;
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

## headless-spike — ACP mode (available)

Read-only investigation. The agent uses `read`/`search` plus a small
read-only bash allowlist (`git status`, `git diff`, `git log`,
`git show`, `git ls-files`, `ls`, `cat`, `head`, `tail`, `wc`,
`file`) and writes its report to `--report-path`. Source files are
never modified — the skill's allowlist enforces this even if the
underlying agent attempts an edit elsewhere.

```
dispatch-opencode \
  --kind headless-spike \
  --mode acp \
  --cwd /Users/cristos/Documents/code/myrepo \
  --branch main \
  --model ollama-cloud/devstral-small-2:24b \
  --report-path reports/spike-2026-04-28.md \
  --prompt-file prompt.md \
  --timeout 900
```

`--agent` defaults to `explore` (opencode's read-only built-in) when
the operator doesn't override it.

## CLI mode example (`--mode cli`, available)

Same `single-file-fix` invocation as the ACP example, with `--mode cli`
substituted:

```
dispatch-opencode \
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

Renders `templates/cli/single-file-fix.sh.j2` to
`.dispatch-opencode/<task-id>/dispatch.sh` and execs it. Replay later
with `bash <task-dir>/dispatch.sh`. macOS without coreutils' `gtimeout`
on PATH will warn and run without timeout enforcement.

## HTTP mode example (`--mode http`, available with caveat)

Same shape, `--mode http`:

```
dispatch-opencode \
  --kind single-file-fix \
  --mode http \
  --cwd /Users/cristos/Documents/code/myrepo \
  --branch feature/auth-rewrite \
  --model ollama-cloud/glm-5.1 \
  --agent build \
  --target-file src/auth/middleware.ts \
  --prompt-file prompt.md \
  --timeout 600
```

Spawns `opencode serve` per task and drives it via REST. **HTTP mode
does not relay permission asks** (issue #16367) — configure permissive
rules in `opencode.json` or accept the risk that ask-tools will hang.
For most cases, prefer ACP mode.
