---
description: Dispatch a subagent task through opencode (single-file-fix, parallel-review-fanout, or headless-spike). Bypasses Claude Code's built-in subagent runtime.
argument-hint: <kind> <target-or-files> <prompt-file> [extra flags]
---

Run the bash tool with the following invocation. Substitute `$1`, `$2`, `$3` and any remaining args from the user's `/oc-dispatch` invocation. Set `$REPO_ROOT` to the absolute path of the project root (use `git rev-parse --show-toplevel`).

```sh
REPO_ROOT="$(git rev-parse --show-toplevel)"
DISPATCH="$REPO_ROOT/skills/opencode-dispatch/bin/opencode-dispatch"

KIND="$1"; shift
case "$KIND" in
  single-file-fix)
    TARGET="$1"; shift
    PROMPT_FILE="$1"; shift
    "$DISPATCH" \
      --kind single-file-fix --mode acp \
      --cwd "$REPO_ROOT" \
      --branch "$(git -C "$REPO_ROOT" branch --show-current)" \
      --target-file "$TARGET" \
      --prompt-file "$PROMPT_FILE" \
      "$@"
    ;;
  parallel-review-fanout)
    TARGETS="$1"; shift            # comma-separated
    SHARED_DECISIONS="$1"; shift
    PROMPT_FILE="$1"; shift
    "$DISPATCH" \
      --kind parallel-review-fanout --mode acp \
      --cwd "$REPO_ROOT" \
      --branch "$(git -C "$REPO_ROOT" branch --show-current)" \
      --target-files "$TARGETS" \
      --shared-decisions "$SHARED_DECISIONS" \
      --prompt-file "$PROMPT_FILE" \
      "$@"
    ;;
  headless-spike)
    REPORT_PATH="$1"; shift
    PROMPT_FILE="$1"; shift
    "$DISPATCH" \
      --kind headless-spike --mode acp \
      --cwd "$REPO_ROOT" \
      --branch "$(git -C "$REPO_ROOT" branch --show-current)" \
      --report-path "$REPORT_PATH" \
      --prompt-file "$PROMPT_FILE" \
      "$@"
    ;;
  *)
    echo "unknown kind: $KIND (expected single-file-fix | parallel-review-fanout | headless-spike)" >&2
    exit 2
    ;;
esac
```

After dispatch completes, surface the rendered task directory and, in ACP mode, the `opencode attach <url> --session <id>` line so the operator can drop into the live session if they want to inspect or steer it.

To install: copy this file to `.claude/commands/oc-dispatch.md` in the consumer project. The operator then invokes:

- `/oc-dispatch single-file-fix src/foo.py prompt.md`
- `/oc-dispatch parallel-review-fanout "src/a.py,src/b.py,src/c.py" docs/shared-decisions.md prompt.md`
- `/oc-dispatch headless-spike reports/spike.md prompt.md`
