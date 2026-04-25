# opencode-subagents-skill

A skill that lets agentic CLIs — Claude Code, Codex, Gemini, and others — run subagents through [opencode](https://opencode.ai) instead of their built-in subagent systems.

## Why

Built-in subagent systems are tied to a single model provider and a single execution surface. Routing subagents through opencode unlocks two things:

- **Broader model choice.** Operators can dispatch tasks to any open-weight or proprietary model that opencode supports, mixing providers per-subagent.
- **Deeper inspection and steering.** Each subagent runs in an opencode session that the operator can attach to, observe, and manually correct mid-flight — instead of being a black-box tool call inside the parent CLI.

## Who it's for

Operators who want to:

- Use heterogeneous models for different subagent roles (a small fast model for triage, a strong model for synthesis, an open-weight model for offline work).
- Watch what a subagent is doing in real time and intervene when it goes off-track.
- Standardize subagent dispatch across multiple host CLIs without re-wiring each one.

## How it works (at a glance)

The skill installs into a host CLI's skill directory and intercepts subagent dispatch. Instead of launching the host's native subagent runtime, it spawns an opencode session, hands it the prompt and tools, and surfaces the result back to the parent. The operator can attach to the live opencode session at any point.

## Status

Early. Interfaces and conventions will change.
