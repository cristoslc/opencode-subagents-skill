# Code Review: 143c72f (rename + compliance audit)

**Refs:** HEAD~1..HEAD
**Platform:** local
**Dispatch:** specialist
**Date:** 2026-04-29

---

## Recommendation: needs_changes

One high-severity pre-existing bug (unbound variable on timeout path) and several medium findings across the new compliance files. The rename itself is clean — no stale `opencode-dispatch` references remain in tracked code.

---

### Security — warning

| Severity | Finding |
|----------|---------|
| low | `allow_implicit_invocation: true` in openai.yaml — could auto-fire skill on tangential prompts |
| low | Gemini TOML `{{args}}` has no input validation guidance |
| low | Dispatch binary path from `git rev-parse` not verified for existence |

### Style — warning

| Severity | Finding |
|----------|---------|
| medium | Gemini TOML `KIND="{{args}}"` — binds entire user input, not just the kind token; weaker contract than Claude Code adapter's positional `$1/$2/$3` |
| low | `openai.yaml` missing top-level `name` field |
| low | `display_name: "Dispatch OpenCode"` diverges from kebab-case skill name |
| low | Stale `.pyc` from old binary name in `__pycache__/` |
| low | `test_permission_handler.py` cleanup assumes fixed directory depth |

### Logic — warning

| Severity | Finding |
|----------|---------|
| **high** | **Unbound `session_id` in timeout handler** — `dispatch-opencode:794`. If `initialize` or `newSession` times out, `session_id` is never assigned but referenced in `session/cancel` in the except block → `NameError` → orphaned `opencode acp` process. Pre-existing, not introduced by rename. |
| medium | `headless-spike.prompt.j2` tells agent to use `glob`/`grep` tools that aren't in the ACP permission allowlist — mid-session confusing rejects |
| low | Gemini TOML `{{args}}` could contain shell metacharacters; model may interpret them |
| low | `allow_implicit_invocation: true` could trigger port allocation on unintended prompts |

### Docs — warning

| Severity | Finding |
|----------|---------|
| medium | `templates_dir: skills/dispatch-opencode/templates` in config example assumes fixed install path; breaks if skill installed in `.agents/skills/` |
| medium | Gemini README rules snippet uses `$(git branch --show-current)` without `-C "$REPO_ROOT"`, diverging from every other adapter |
| medium | `agents/openai.yaml` has no inline comments explaining its purpose or linking to docs |
| low | `oc-dispatch.toml` missing cross-reference back to SKILL.md |

---

## Finding Counts

| Agent | Critical | High | Medium | Low | Total |
|-------|----------|------|--------|-----|-------|
| security | 0 | 0 | 0 | 3 | 3 |
| style | 0 | 0 | 1 | 4 | 5 |
| logic | 0 | 1 | 1 | 2 | 4 |
| docs | 0 | 0 | 3 | 1 | 4 |
| **total** | **0** | **1** | **5** | **10** | **16** |

---

## Merged Findings (deduplicated)

### 1. [high] Unbound `session_id` in timeout handler
**Source:** logic
**File:** `skills/dispatch-opencode/bin/dispatch-opencode:794`
**Fix:** Initialize `session_id = None` before the try block. Guard the except clause: `if session_id is not None: await client.notify("session/cancel", {"sessionId": session_id})`

### 2. [medium] Gemini TOML `{{args}}` binds full input as KIND
**Source:** style, security, logic (3 agents converged)
**File:** `skills/dispatch-opencode/templates/runtimes/gemini/oc-dispatch.toml:19`
**Fix:** Rewrite prompt to use positional arg parsing: `$1 = kind`, `$2 = target`, `$3 = prompt-file`. Add validation: "If kind is not one of the three valid values, refuse."

### 3. [medium] Prompt names `glob`/`grep` tools not in ACP allowlist
**Source:** logic
**File:** `skills/dispatch-opencode/templates/acp/headless-spike.prompt.j2:28`
**Fix:** Change prompt text to "read and search tools" or add `glob`/`grep` to the headless-spike ALLOWLIST.

### 4. [medium] `templates_dir` assumes fixed install path
**Source:** docs
**File:** `skills/dispatch-opencode/SKILL.md:270`
**Fix:** Add comment: `# adjust if skill is installed elsewhere (e.g. .agents/skills/dispatch-opencode/templates)`

### 5. [medium] Gemini README rules snippet missing `-C` on `git branch`
**Source:** docs
**File:** `skills/dispatch-opencode/templates/runtimes/gemini/README.md:46`
**Fix:** Change to `$(git -C "$REPO_ROOT" branch --show-current)` to match other adapters.

### 6. [medium] `agents/openai.yaml` lacks inline documentation
**Source:** docs, style
**File:** `skills/dispatch-opencode/agents/openai.yaml:1`
**Fix:** Add header comment explaining purpose and linking to Codex README.

### 7. [low] Stale `.pyc` from pre-rename binary
**Source:** style
**File:** `skills/dispatch-opencode/bin/__pycache__/`
**Fix:** `rm skills/dispatch-opencode/bin/__pycache__/opencode-dispatch*.pyc`

### 8. [low] Test cleanup assumes fixed directory depth
**Source:** style
**File:** `skills/dispatch-opencode/tests/test_permission_handler.py:256`
**Fix:** Replace `rmdir()` chain with `shutil.rmtree(target.parent.parent, ignore_errors=True)`

### 9. [low] `oc-dispatch.toml` missing SKILL.md cross-reference
**Source:** docs
**File:** `skills/dispatch-opencode/templates/runtimes/gemini/oc-dispatch.toml:1`
**Fix:** Add: `# Full argument table and alternate modes: see SKILL.md in the skill directory.`

---

*Generated by code-review — multi-agent code review system*
