#!/usr/bin/env bash
# validate-run.sh — post-run validation of a dispatch task directory.
# Exits 0 on healthy completion, non-zero with a diagnosis otherwise.
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

if [ ! -s "$EVENTS" ]; then
  err "events.jsonl missing or empty — likely silent stall"
fi

# Idle-completion check.
# `opencode run --format json` emits NDJSON. A session.status event has the
# shape {"type":"session.status","properties":{"status":{"type":"idle|...|error"}}}.
# The wait condition in opencode/packages/opencode/src/cli/cmd/run.ts is
# the inner status.type === "idle"; trove source `cli-run-and-attach`
# documents the same.
LAST_STATUS=$(jq -r 'select(.type=="session.status") | .properties.status.type // empty' "$EVENTS" | tail -1)
[ "$LAST_STATUS" = "idle" ] \
  || err "stream did not end at session.status:idle (last status: '${LAST_STATUS:-<none>}')"

# session.error surfacing — best-effort. opencode does not always emit
# session.error on provider 429 / other API errors (trove failure-modes
# notes #8203 and #1329).
if jq -e 'select(.type=="session.error")' "$EVENTS" >/dev/null 2>&1; then
  warn "session.error events present — see $EVENTS"
fi

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

printf 'validate-run: ok task-dir=%s\n' "$TASK_DIR"
