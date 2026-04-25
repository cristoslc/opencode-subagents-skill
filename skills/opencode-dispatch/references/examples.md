# Examples

Concrete invocations of `opencode-dispatch`. Update when adding a kind.

## single-file-fix

A focused edit on one file. Backed by the `single-file-fix.sh.j2` template.

```
opencode-dispatch \
  --kind single-file-fix \
  --cwd /Users/cristos/Documents/code/myrepo \
  --branch feature/auth-rewrite \
  --model ollama-cloud/glm-5.1 \
  --agent build \
  --target-file src/auth/middleware.ts \
  --prompt-file prompt.md \
  --timeout 600
```

Renders to `.opencode-dispatch/<task-id>/dispatch.sh`. The operator can `cd`
to that directory and re-run `bash dispatch.sh` for an exact replay.

## parallel-review-fanout (planned)

N independent agents, N files, one shared-decisions document passed into
each agent's prompt. Pattern validated in research-keeper INITIATIVE-003
retro (4 agents, 9 rounds, 0 merge conflicts).

```
opencode-dispatch \
  --kind parallel-review-fanout \
  --cwd /Users/cristos/Documents/code/myrepo \
  --branch design-iteration \
  --model ollama-cloud/glm-5.1 \
  --agent build \
  --shared-decisions docs/iter/shared-decisions-v3.md \
  --target-files docs/spec-a.md,docs/spec-b.md,docs/spec-c.md,docs/spec-d.md \
  --timeout 1200 \
  --parallel 4
```

Renders one `dispatch.sh` per target file under
`.opencode-dispatch/<task-id>/<file-slug>/`, then execs them in parallel.

## headless-spike (planned)

Read-only investigation. The agent writes a report to a known path; source
is not modified.

```
opencode-dispatch \
  --kind headless-spike \
  --cwd /Users/cristos/Documents/code/myrepo \
  --branch main \
  --model anthropic/claude-sonnet-4-5 \
  --agent explore \
  --report-path reports/spike-2026-04-25.md \
  --prompt-file prompt.md \
  --timeout 900
```

The `explore` agent's read-only permission profile prevents accidental
edits.
