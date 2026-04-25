---
source-id: providers-and-models
title: "opencode provider and model configuration"
type: docs
fetched: 2026-04-25
verified: false
---

# Providers and models

Docs: <https://opencode.ai/docs/providers/>, <https://opencode.ai/docs/models/>.

## Files

- Auth: `~/.local/share/opencode/auth.json`.
- Global config: `~/.config/opencode/opencode.json`.
- Project config: `opencode.json` at the project root.

`auth.json` entry:

```json
{ "provider-id": { "type": "api", "key": "raw-api-key-string" } }
```

## Model string format

`provider_id/model_id`. Examples: `anthropic/claude-sonnet-4-5`, `openai/gpt-4.1-mini`, `ollama/qwen3-coder:480b`, `ollama/qwen3-coder:480b-cloud` (cloud suffix), `openrouter/openai/gpt-oss-120b:free`.

## Local Ollama

```json
{
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "options": { "baseURL": "http://localhost:11434/v1" },
      "models": { "llama3.1": { "name": "Llama 3.1" } }
    }
  }
}
```

## Ollama Cloud

Append `-cloud` to the model ID: `ollama/qwen3-coder:480b-cloud`. Auth via Ollama account.

## OpenRouter

```json
{
  "provider": {
    "openrouter": {
      "models": { "openai/gpt-oss-120b:free": {} }
    }
  }
}
```

Note: for some open-weight models hosted on OpenRouter (Kimi K2 in particular — see issue #1329 thread), the built-in `openrouter` provider has stalled mid-task in headless. Workaround is to define the same endpoint under `@ai-sdk/openai-compatible`:

```json
{
  "provider": {
    "openrouter-compat": {
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "https://openrouter.ai/api/v1",
        "headers": { "Authorization": "Bearer {env:OPENROUTER_API_KEY}" }
      },
      "models": { "moonshotai/kimi-k2": {} }
    }
  }
}
```

## Custom OpenAI-compatible

Use `@ai-sdk/openai-compatible` for `/v1/chat/completions` endpoints; `@ai-sdk/openai` for `/v1/responses`.

## Variants

`--variant high|max|minimal` selects reasoning effort. Anthropic supports `high`, `max`. OpenAI supports `none|low|medium|high`. Custom variants can be defined per model in config.

## Selection priority

CLI flag → project config → global config → last-used → internal default.

## Inline config — `OPENCODE_CONFIG_CONTENT`

Discussed at issue #13219. Set `OPENCODE_CONFIG_CONTENT` to a JSON string and opencode loads it as if it were a config file. **Important caveat:** `{env:VAR}` and `{file:path}` token interpolation is bypassed when content is loaded from this env var — tokens stay literal. For headless dispatch, either:

- Pre-interpolate the JSON before exporting, or
- Write the config to a real file and point `OPENCODE_CONFIG=/path/to/file`.

## Sources

- <https://opencode.ai/docs/providers/>
- <https://opencode.ai/docs/models/>
- <https://github.com/sst/opencode/issues/13219>
- <https://github.com/sst/opencode/issues/1329>
- <https://github.com/sst/opencode/blob/dev/packages/opencode/src/flag/flag.ts>
