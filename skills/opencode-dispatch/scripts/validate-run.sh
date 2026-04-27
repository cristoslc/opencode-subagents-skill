#!/usr/bin/env bash
# validate-run.sh — post-run validation of a dispatch task directory.
# Exits 0 on healthy completion, non-zero with a diagnosis otherwise.
#
# Auto-detects the dispatch mode from events.jsonl:
#   - ACP mode: lines are JSON-RPC envelopes (`{"jsonrpc":"2.0",...}`).
#     Idle signal = response to session/prompt with stopReason == end_turn.
#     Errors = JSON-RPC error responses, or stopReason in {refusal, max_tokens}.
#   - CLI mode: lines are raw opencode events (`{"type":"...",...}`).
#     Idle signal = last session.status event has properties.status.type == idle.
#
# Either mode strips </think> blocks from stdout.log and events.jsonl
# (reasoning-model leakage; trove failure-modes).
#
# Usage: validate-run.sh <task-dir>
#
# Requires: jq, python3.

set -euo pipefail

err()  { printf 'validate-run: %s\n' "$*" >&2; exit 1; }
warn() { printf 'validate-run: warn %s\n' "$*" >&2; }

[ "$#" -ge 1 ] || err "missing task-dir"
TASK_DIR="$1"

case "$TASK_DIR" in
  /*) ;;
  *)  err "task-dir must be absolute: $TASK_DIR" ;;
esac
case "$TASK_DIR" in
  *[!A-Za-z0-9_./:-]*) err "task-dir contains unsafe characters: $TASK_DIR" ;;
esac
[ -d "$TASK_DIR" ] || err "no such task-dir: $TASK_DIR"

command -v jq      >/dev/null 2>&1 || err "jq is required but not installed"
command -v python3 >/dev/null 2>&1 || err "python3 is required but not installed"

EVENTS="$TASK_DIR/events.jsonl"
STDOUT="$TASK_DIR/stdout.log"

[ -s "$EVENTS" ] || err "events.jsonl missing or empty — likely silent stall"

# Detect mode by checking whether the first line carries a jsonrpc field.
FIRST_HAS_JSONRPC=$(head -n 1 "$EVENTS" | jq -r '.jsonrpc // empty' 2>/dev/null || true)
if [ -n "$FIRST_HAS_JSONRPC" ]; then
  MODE="acp"
else
  MODE="cli"
fi
printf 'validate-run: mode=%s\n' "$MODE"

case "$MODE" in
  acp)
    # The last JSON-RPC response (a line with both `id` and `result|error`,
    # no `method`) is the response to session/prompt. stopReason == end_turn
    # is the idle signal; refusal / max_turn_requests / cancelled are
    # documented but treated as warnings rather than failures.
    LAST_RESPONSE=$(jq -c 'select(.id != null and (.result != null or .error != null) and (.method == null))' "$EVENTS" | tail -1)
    [ -n "$LAST_RESPONSE" ] || err "no JSON-RPC response found in events.jsonl"

    if echo "$LAST_RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
      msg=$(echo "$LAST_RESPONSE" | jq -r '.error.message // "<no message>"')
      err "session/prompt returned error: $msg"
    fi
    STOP_REASON=$(echo "$LAST_RESPONSE" | jq -r '.result.stopReason // empty')
    case "$STOP_REASON" in
      end_turn) ;;
      "")       err "last response has no stopReason: $LAST_RESPONSE" ;;
      refusal|max_tokens|max_turn_requests|cancelled) warn "stopReason=$STOP_REASON (not end_turn)" ;;
      *)        warn "unrecognized stopReason: $STOP_REASON" ;;
    esac

    # Surface any tool-call failures from session/update notifications.
    FAILED_TOOLS=$(jq -r 'select(.method == "session/update")
                          | .params.update // .params
                          | select(.sessionUpdate == "tool_call_update" and .status == "failed")
                          | (.toolCallId // "?")' "$EVENTS" | sort -u || true)
    if [ -n "$FAILED_TOOLS" ]; then
      warn "tool_call(s) failed: $(echo "$FAILED_TOOLS" | tr '\n' ' ')"
    fi
    ;;

  cli)
    # opencode --format json events shape:
    # {"type":"session.status","properties":{"status":{"type":"idle|...|error"}}}
    LAST_STATUS=$(jq -r 'select(.type=="session.status") | .properties.status.type // empty' "$EVENTS" | tail -1)
    [ "$LAST_STATUS" = "idle" ] \
      || err "stream did not end at session.status:idle (last status: '${LAST_STATUS:-<none>}')"

    if jq -e 'select(.type=="session.error")' "$EVENTS" >/dev/null 2>&1; then
      warn "session.error events present — see $EVENTS"
    fi
    ;;
esac

# Strip <think>…</think> blocks (and stray </think> tokens) from captured
# logs. Reasoning models like glm-5.x and kimi-k2-thinking sometimes leak
# them; the leak corrupts the visible log but not the file edits.
strip_think() {
  local target="$1"
  [ -f "$target" ] || return 0
  grep -q '</think>' "$target" || return 0
  warn "stripping </think> blocks from $target"
  python3 - "$target" <<'PY'
import os, re, sys, tempfile
p = sys.argv[1]
# Refuse to follow symlinks. The task-dir path is operator-supplied; a
# pre-staged symlink at this path would let the rewrite below overwrite
# whatever the symlink points to (crontabs, authorized_keys, source files
# the dispatch process can write).
if os.path.islink(p):
    sys.exit(f"refusing to rewrite symlink: {p}")
fd = os.open(p, os.O_RDONLY | os.O_NOFOLLOW)
with os.fdopen(fd, "r", encoding="utf-8", errors="replace") as fh:
    s = fh.read()
s = re.sub(r"<think>.*?</think>\s*", "", s, flags=re.DOTALL)
s = s.replace("</think>", "")
d = os.path.dirname(p) or "."
with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False, dir=d) as tf:
    tf.write(s)
    tmp = tf.name
os.replace(tmp, p)
PY
}

strip_think "$STDOUT"
strip_think "$EVENTS"

printf 'validate-run: ok task-dir=%s mode=%s\n' "$TASK_DIR" "$MODE"
