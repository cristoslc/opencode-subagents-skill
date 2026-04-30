# Agentic CLI Skill/Command Definition Standards

Research date: 2026-04-29

---

## 1. Claude Code (Anthropic)

**Canonical docs:** <https://code.claude.com/docs/en/slash-commands>
**Open standard:** <https://agentskills.io/specification> (Claude Code extends this)

### File Structure

| Scope      | Path                                          | Notes                          |
|------------|-----------------------------------------------|--------------------------------|
| Enterprise | Managed settings (see settings docs)          | All users in org               |
| Personal   | `~/.claude/skills/<name>/SKILL.md`            | All projects                   |
| Project    | `.claude/skills/<name>/SKILL.md`              | This project only              |
| Plugin     | `<plugin>/skills/<name>/SKILL.md`              | Namespaced `plugin:name`       |
| Legacy     | `.claude/commands/<name>.md`                  | Still works; skills preferred   |
| Legacy     | `~/.claude/commands/<name>.md`                | Still works; skills preferred   |

**Directory structure:**

```
skill-name/
├── SKILL.md           # Required — main instructions + frontmatter
├── template.md        # Optional — template for Claude to fill
├── examples/
│   └── sample.md      # Optional — example output
└── scripts/
    └── validate.sh    # Optional — script Claude can execute
```

### SKILL.md Frontmatter (YAML between `---` markers)

| Field                        | Required?   | Type             | Description |
|------------------------------|-------------|------------------|-------------|
| `name`                       | No          | string           | Display name; defaults to directory name. Lowercase, numbers, hyphens only. Max 64 chars. |
| `description`                | Recommended | string           | What skill does + when to use it. Truncated at 1,536 chars in skill listing. If omitted, uses first paragraph of markdown body. |
| `when_to_use`                | No          | string           | Appended to `description` in listing. Counts toward 1,536-char cap. |
| `argument-hint`              | No          | string           | Autocomplete hint, e.g. `[issue-number]` |
| `arguments`                  | No          | string or list   | Named positional args for `$name` substitution |
| `disable-model-invocation`   | No          | boolean          | `true` = only user can invoke (prevents auto-trigger). Default: `false` |
| `user-invocable`             | No          | boolean          | `false` = hidden from `/` menu (background knowledge). Default: `true` |
| `allowed-tools`              | No          | string or list   | Tools pre-approved while skill active. Space-separated or YAML list. |
| `model`                      | No          | string           | Model override while active, or `inherit`. |
| `effort`                     | No          | string           | `low` / `medium` / `high` / `xhigh` / `max` |
| `context`                    | No          | string           | Set to `fork` to run in subagent context |
| `agent`                      | No          | string           | Subagent type when `context: fork` (e.g. `Explore`, `Plan`, custom agent) |
| `hooks`                      | No          | object           | Lifecycle hooks scoped to this skill |
| `paths`                      | No          | string or list   | Glob patterns limiting auto-activation to matching files |
| `shell`                      | No          | string           | `bash` (default) or `powershell` for `!`command`` blocks |

### String Substitutions

| Variable                 | Description |
|--------------------------|-------------|
| `$ARGUMENTS`             | All arguments as typed |
| `$ARGUMENTS[N]` / `$N`   | 0-based positional arg |
| `$name`                  | Named arg from `arguments` frontmatter |
| `${CLAUDE_SESSION_ID}`   | Current session ID |
| `${CLAUDE_EFFORT}`       | Current effort level |
| `${CLAUDE_SKILL_DIR}`    | Directory containing this SKILL.md |

### Dynamic Context Injection

- **Inline shell:** `` !`command` `` — runs before sending to Claude; output replaces placeholder
- **Fenced block:** ` ```! ` — multi-line shell command block
- **File reference:** `@path/to/file` — embeds file content

### Invocation

- User types `/skill-name [args]`
- Claude auto-invokes when description matches conversation context (unless `disable-model-invocation: true`)
- MCP prompts also appear as `/mcp__servername__promptname`

### Precedence

Enterprise > Personal > Project. Plugin skills are namespaced (`plugin:skill`) so never conflict.

### Key Constraints

- Combined `description` + `when_to_use` capped at **1,536 chars** in skill listing
- Full skill listing budget: 1% of context window (fallback 8,000 chars), adjustable via `SLASH_COMMAND_TOOL_CHAR_BUDGET`
- Auto-compaction carries invoked skills: first 5,000 tokens each, combined budget 25,000 tokens
- SKILL.md recommended under 500 lines
- Live change detection: edits to skill directories take effect without restart

---

## 2. OpenAI Codex CLI

**Canonical docs:**
- Skills: <https://developers.openai.com/codex/skills>
- Config: <https://developers.openai.com/codex/config-reference>
- Sample config: <https://developers.openai.com/codex/config-sample>
- AGENTS.md: <https://developers.openai.com/codex/guides/agents-md>
- Open standard: <https://agentskills.io/specification>

### File Structure

**Skills** follow the [Agent Skills](https://agentskills.io) open standard (same `SKILL.md` format as Claude Code):

| Scope      | Path                                       | Notes                          |
|------------|--------------------------------------------|--------------------------------|
| REPO       | `$CWD/.agents/skills/<name>/SKILL.md`      | Current working directory      |
| REPO       | `$CWD/../.agents/skills/<name>/SKILL.md`   | Parent folder in git repo      |
| REPO       | `$REPO_ROOT/.agents/skills/<name>/SKILL.md` | Repo root                     |
| USER       | `$HOME/.agents/skills/<name>/SKILL.md`      | Personal, all repos            |
| ADMIN      | `/etc/codex/skills/<name>/SKILL.md`        | System-wide                    |
| SYSTEM     | Bundled by OpenAI                          | e.g. `skill-creator`, `plan`   |

```
skill-name/
├── SKILL.md           # Required — name + description (frontmatter) + instructions
├── scripts/           # Optional
├── references/        # Optional
├── assets/            # Optional
└── agents/
    └── openai.yaml    # Optional — UI metadata, policy, tool dependencies
```

### SKILL.md Frontmatter (YAML)

Per the Agent Skills open standard:

| Field           | Required | Constraints                                                      |
|-----------------|----------|------------------------------------------------------------------|
| `name`          | Yes      | Max 64 chars. Lowercase, numbers, hyphens only. No leading/trailing/consecutive hyphens. Must match directory name. |
| `description`   | Yes      | Max 1024 chars. Non-empty. What skill does + when to use it.     |
| `license`       | No       | License name or reference to bundled file                        |
| `compatibility` | No       | Max 500 chars. Environment requirements                          |
| `metadata`      | No       | Arbitrary key-value mapping                                      |
| `allowed-tools`  | No       | Space-separated string of pre-approved tools (experimental)      |

### agents/openai.yaml (Optional)

Extends a skill with UI/policy/dependency metadata for the Codex App:

```yaml
interface:
  display_name: "User-facing name"
  short_description: "User-facing description"
  icon_small: "./assets/small-logo.svg"
  icon_large: "./assets/large-logo.png"
  brand_color: "#3B82F6"
  default_prompt: "Surrounding prompt to use with skill"

policy:
  allow_implicit_invocation: false   # Default: true. When false, must use $skill-name

dependencies:
  tools:
    - type: "mcp"
      value: "openaiDeveloperDocs"
      description: "OpenAI Docs MCP server"
      transport: "streamable_http"
      url: "https://developers.openai.com/mcp"
```

### Skill Enable/Disable in config.toml

```toml
[[skills.config]]
path = "/path/to/skill/SKILL.md"
enabled = false
```

### Config File (~/.codex/config.toml)

All Codex configuration uses TOML. Key locations:

| Scope   | Path                            |
|---------|---------------------------------|
| User    | `~/.codex/config.toml`          |
| Project | `.codex/config.toml`           |
| Admin   | Managed via `requirements.toml` |

Config layers: project configs loaded from root down to CWD (closest wins, trusted projects only).

### AGENTS.md (Custom Instructions)

Codex reads `AGENTS.md` files for persistent instructions (equivalent to CLAUDE.md):

| Scope   | Path                       |
|---------|----------------------------|
| Global  | `~/.codex/AGENTS.md`       |
| Project | `./AGENTS.md`              |
| Nested  | `./subdir/AGENTS.md`       |

Fallback filenames configurable in config.toml:
```toml
project_doc_fallback_filenames = ["TEAM_GUIDE.md", ".agents.md"]
project_doc_max_bytes = 65536
```

### Invocation

- **Explicit:** Type `$skill-name` or `/skills` in prompt, or select from skill picker
- **Implicit:** Codex auto-selects when task matches `description`
- **Context budget:** Initial skill list capped at ~2% of context window (or 8,000 chars fallback). Descriptions shortened first; very large sets may omit some skills.

### Slash Commands (CLI built-ins only)

Codex CLI slash commands are **built-in only** (not user-definable in the same way as Claude). Notable commands: `/model`, `/permissions`, `/review`, `/compact`, `/plan`, `/fork`, `/diff`, `/mcp`, `/init`, `/status`, `/experimental`, `/personality`, `/fast`, `/apps`, `/plugins`, `/agent`.

Custom reusable workflows are expressed as **Skills** (via `$skill-name` syntax), not as slash commands.

### Plugins (Distribution Unit)

Skills are the authoring format; plugins are the distribution unit. A plugin can bundle one or more skills plus MCP config, app mappings, and presentation assets. See: <https://developers.openai.com/codex/plugins/build>

---

## 3. Google Gemini CLI

**Canonical docs:**
- Custom commands: <https://geminicli.com/docs/cli/custom-commands/>
- Agent Skills: <https://geminicli.com/docs/cli/skills/>
- Configuration: <https://geminicli.com/docs/reference/configuration/>
- System prompt override: <https://geminicli.com/docs/cli/system-prompt/>
- Context files: <https://geminicli.com/docs/cli/gemini-md/>

Gemini CLI has **two distinct extensibility mechanisms**: Custom Commands (TOML-based slash commands) and Agent Skills (SKILL.md-based expertise bundles).

### 3A. Custom Commands (Slash Commands)

**File format:** TOML (`.toml` extension required)

**File locations:**

| Scope    | Path                                    | Notes                        |
|----------|-----------------------------------------|------------------------------|
| User     | `~/.gemini/commands/<name>.toml`       | Global across all projects   |
| Project  | `<project>/.gemini/commands/<name>.toml` | Project-specific           |

**Naming:** Path relative to `commands/` becomes the command name. Subdirectories create namespaces with `:` separator.

- `~/.gemini/commands/test.toml` → `/test`
- `.gemini/commands/git/commit.toml` → `/git:commit`

**Precedence:** Project commands override user commands with the same name.

**Hot reload:** Run `/commands reload` after creating/modifying `.toml` files.

#### TOML Fields

| Field         | Required | Type   | Description |
|---------------|----------|--------|-------------|
| `prompt`      | **Yes**  | string | The prompt sent to the model. Single-line or multi-line. |
| `description` | No       | string | One-line description shown in `/help`. If omitted, generic description generated from filename. |

#### Argument Handling

| Syntax        | Behavior |
|---------------|---------|
| `{{args}}`    | Replaced with user-typed text. Inside `!{...}` blocks, auto shell-escaped. |
| (no `{{args}}`) | Arguments appended after two newlines if provided; prompt sent as-is if no args. |

#### Dynamic Features

| Syntax        | Description |
|---------------|-------------|
| `!{command}`  | Shell command execution; output injected into prompt. User confirmation required before execution. |
| `@{path}`     | File/directory content injection. Supports multimodal (images, PDFs, audio, video). Processed **before** `!{}` and `{{args}}`. |
| `{{args}}`    | Argument substitution. Auto shell-escaped inside `!{...}`. |

**Processing order:** `@{...}` → `!{...}` → `{{args}}`

#### Security

- Shell commands in `!{...}` require user confirmation
- Arguments inside `!{...}` are auto shell-escaped to prevent injection
- `!{...}` parser requires balanced braces; for unbalanced braces, wrap in external script

### 3B. Agent Skills (SKILL.md)

**Follows the [Agent Skills](https://agentskills.io) open standard** (same as Claude Code and Codex).

**File locations:**

| Scope     | Path                                    | Notes                        |
|-----------|-----------------------------------------|------------------------------|
| Workspace | `.gemini/skills/<name>/SKILL.md`        | Committed to VCS             |
| Workspace | `.agents/skills/<name>/SKILL.md`        | Alias — takes precedence     |
| User      | `~/.gemini/skills/<name>/SKILL.md`      | Personal across all projects |
| User      | `~/.agents/skills/<name>/SKILL.md`      | Alias — takes precedence     |
| Extension | Bundled within installed extensions     |                              |

**Precedence:** Workspace > User > Extension. Within same tier, `.agents/skills/` > `.gemini/skills/`.

#### SKILL.md Frontmatter

Follows the Agent Skills spec (same fields as Codex — `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`).

#### Activation Flow

1. **Discovery:** Name + description injected into system prompt at session start
2. **Activation:** Gemini calls `activate_skill` tool when task matches description
3. **Consent:** User sees confirmation prompt (name, purpose, directory path)
4. **Injection:** SKILL.md body + folder structure added to conversation; directory added to allowed file paths
5. **Execution:** Skill guidance prioritized for session duration

#### Management Commands

- `/skills list` — view all discovered skills
- `/skills link <path>` — symlink skills from a directory
- `/skills disable <name>` / `/skills enable <name>` — toggle (default scope: user)
- `/skills reload` — refresh discovered skills
- `gemini skills install <source>` — install from git repo, local dir, or `.skill` file
- `gemini skills uninstall <name>` — remove by name

### 3C. Context Files (GEMINI.md)

Hierarchical markdown files providing persistent instructions (equivalent to CLAUDE.md / AGENTS.md):

| Scope          | Path                                  |
|----------------|---------------------------------------|
| Global         | `~/.gemini/GEMINI.md`                |
| Project root   | `./GEMINI.md`                         |
| Ancestor dirs  | Walked from CWD to project root       |
| Sub-directories| Scanned for component-specific context|

File references: `@./path/to/file.md` syntax to include other files.

### 3D. System Prompt Override

Set `GEMINI_SYSTEM_MD` environment variable:
- `true` or `1` → uses `./.gemini/system.md`
- Any other string → treated as absolute path to custom markdown file

### 3E. Settings

- `~/.gemini/settings.json` — user settings
- `.gemini/settings.json` — project settings
- Supports MCP server configuration, sandbox profiles, custom policies

### 3F. Extensions

Extensions package skills, custom commands, and MCP server configs into a single installable unit. See: <https://geminicli.com/docs/extensions/>

---

## Cross-Platform Comparison

| Aspect                  | Claude Code                          | Codex CLI                              | Gemini CLI                             |
|-------------------------|--------------------------------------|----------------------------------------|----------------------------------------|
| **Skill format**        | SKILL.md (YAML frontmatter + MD)     | SKILL.md (YAML frontmatter + MD)       | SKILL.md (YAML frontmatter + MD)       |
| **Skill standard**      | Agent Skills spec + extensions       | Agent Skills spec + openai.yaml        | Agent Skills spec                      |
| **Command format**      | SKILL.md (merged with skills)        | Built-in only; skills via `$name`      | TOML (`<name>.toml`)                   |
| **Skill locations**     | `.claude/skills/`, `~/.claude/skills/` | `.agents/skills/`, `~/.agents/skills/` | `.gemini/skills/`, `~/.gemini/skills/`, `.agents/skills/` |
| **Command locations**   | `.claude/commands/` (legacy)         | N/A (built-in only)                    | `.gemini/commands/`, `~/.gemini/commands/` |
| **Config file**         | `CLAUDE.md`                          | `config.toml` (TOML)                   | `settings.json` (JSON)                |
| **Instructions file**   | `CLAUDE.md`                          | `AGENTS.md`                            | `GEMINI.md`                            |
| **Required frontmatter**| None (description recommended)       | `name` + `description`                 | `name` + `description` (skills); `prompt` (commands) |
| **Shell injection**     | `!`command``                         | Via scripts/ directory                  | `!{command}`                           |
| **File injection**      | `@path`                              | Via references/ directory              | `@{path}`                              |
| **Arg substitution**   | `$ARGUMENTS`, `$N`, `$name`          | Not in skills (handled by prompt)      | `{{args}}`                             |
| **Auto-invocation**     | Yes (via description matching)       | Yes (via description matching)         | Yes (via `activate_skill` tool + consent) |
| **Disable auto-invoke** | `disable-model-invocation: true`     | `allow_implicit_invocation: false` in openai.yaml | `/skills disable <name>` |
| **Distribution**        | Plugins                              | Plugins                                | Extensions                             |

### Key Observation: The Agent Skills Convergence

All three platforms now support the [Agent Skills open standard](https://agentskills.io) for the `SKILL.md` format. The core spec defines:

- **Required:** `name` (max 64, lowercase-hyphen) + `description` (max 1024)
- **Optional:** `license`, `compatibility`, `metadata`, `allowed-tools`
- **Structure:** Directory with `SKILL.md` + optional `scripts/`, `references/`, `assets/`

Each platform then extends the spec with its own additional frontmatter fields and features:

| Extension        | Claude Code additions                                      | Codex additions                     | Gemini additions    |
|------------------|-----------------------------------------------------------|-------------------------------------|---------------------|
| Frontmatter      | `argument-hint`, `arguments`, `disable-model-invocation`, `user-invocable`, `model`, `effort`, `context`, `agent`, `hooks`, `paths`, `shell`, `when_to_use` | — (uses `openai.yaml` instead)     | —                   |
| Metadata file    | —                                                          | `agents/openai.yaml` (UI, policy, deps) | —              |
| Command format   | SKILL.md doubles as command                                | Built-in slash + `$skill` invocation | Separate `.toml` command files |
