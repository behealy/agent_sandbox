---
name: agent-model-config
description: Sync available models from a local OpenAI-compatible LLM server into both OpenCode and PI agent config files. Use when configuring or updating models for Ollama, LM Studio, vLLM, or llama.cpp before building the image.
---

# Agent Model Config Sync

Sync discovered models from a running local LLM server into `opencode-config.json` and `pi-models.json`. This skill does not build or run the image — it only updates config files.

## Prerequisites

- A running local LLM server (Ollama, LM Studio, vLLM, etc.)
- `curl` available on the host
- Config files exist at their baked-in paths:
  - OpenCode: `/home/agentuser/.config/opencode/opencode.json` (or edit locally and rebuild)
  - PI: `/home/agentuser/.pi/agent/models.json` (or edit locally and rebuild)

## Step 1 — Discover Available Models

Query the server's models endpoint. The exact URL depends on your provider:

| Provider | Endpoint | Notes |
|----------|----------|-------|
| **Ollama** | `http://localhost:11434/api/tags` | Returns `name` field (no `/v1`) |
| **LM Studio** | `http://localhost:1234/v1/models` | Standard OpenAI format |
| **vLLM** | `http://localhost:8000/v1/models` | Standard OpenAI format |
| **llama.cpp** | `http://localhost:11435/api/tags` | Ollama-compatible format |

```bash
# LM Studio / vLLM (OpenAI-compatible)
curl -s http://localhost:1234/v1/models | jq '.data[].id'

# Ollama / llama.cpp (Ollama-compatible)
curl -s http://localhost:11434/api/tags | jq -r '.models[].name'
```

Capture the list of model IDs. You'll use these in both config files below.

## Step 2 — Update OpenCode Config (`opencode-config.json`)

OpenCode uses a flat `provider` object with an array of models:

```json
{
  "provider": {
    "type": "openai",
    "baseUrl": "http://localhost:1234/v1",
    "apiKey": "",
    "models": [
      { "id": "<model-id>", "name": "<human-readable-name>" }
    ]
  }
}
```

### Procedure

1. Read the existing `opencode-config.json` to preserve any non-model settings (e.g., `systemPrompt`, `temperature`).
2. Replace or append model entries under `provider.models`.
3. For each discovered model ID, create an entry with:
   - `id`: the exact model identifier from Step 1
   - `name`: a human-readable label (derive from the ID; e.g., `"llama-3.1-turbo"` → `"Llama 3.1 Turbo"`)
4. Optional fields (`contextWindow`, `maxTokens`) — add manually if known, otherwise omit and OpenCode will use defaults.

### Example: LM Studio with three models

```json
{
  "provider": {
    "type": "openai",
    "baseUrl": "http://localhost:1234/v1",
    "apiKey": "",
    "models": [
      { "id": "llama-3.1-turbo", "name": "Llama 3.1 Turbo" },
      { "id": "mistral-small-24b-instruct", "name": "Mistral Small 24B Instruct" },
      { "id": "gemma-2-27b-it", "name": "Gemma 2 27B IT" }
    ]
  }
}
```

See [Opencode_Model_Config.md](docs/Opencode_Model_Config.md) for full field reference.

## Step 3 — Update PI Config (`pi-models.json`)

PI uses a nested `providers` object keyed by provider name:

```json
{
  "providers": {
    "<provider-name>": {
      "baseUrl": "http://localhost:<port>/v1",
      "api": "openai-completions",
      "apiKey": "<key-or-empty>",
      "models": [
        { "id": "<model-id>" }
      ]
    }
  }
}
```

### Procedure

1. Read the existing `pi-models.json` to preserve any non-model provider settings (e.g., `compat`, custom headers).
2. Under the appropriate provider key, replace or append model entries in the `models` array.
3. For each discovered model ID, create an entry with at minimum:
   - `id`: the exact model identifier from Step 1
4. Optional fields (`name`, `reasoning`, `contextWindow`, `maxTokens`, `cost`) — add manually if known.

### Provider-specific notes

| Provider | Provider Key | baseUrl Pattern | apiKey | api | Notes |
|----------|-------------|-----------------|--------|-----|-------|
| Ollama | `ollama` | `http://localhost:11434/v1` | `"ollama"` | `"openai-completions"` | Most compatible; set `compat.supportsDeveloperRole: false` if needed |
| LM Studio | `lm-studio` | `http://localhost:1234/v1` | `""` (empty) | `"openai-completions"` | May need `compat.supportsReasoningEffort: false` for reasoning models |
| vLLM | `vllm` | `http://localhost:8000/v1` | your key | `"openai-completions"` | Usually fully compatible; no compat overrides needed |

### Example: Ollama with three models

```json
{
  "providers": {
    "ollama": {
      "baseUrl": "http://localhost:11434/v1",
      "api": "openai-completions",
      "apiKey": "ollama",
      "models": [
        { "id": "llama3.2" },
        { "id": "mistral-nemo" },
        { "id": "gemma2:27b" }
      ]
    }
  }
}
```

See [PI_Model_Config.md](docs/PI_Model_Config.md) for full field reference, including compat overrides and thinking level maps.

## Step 4 — Validate

After editing the config files (locally or inside the container), verify they parse correctly:

```bash
# Inside the container
docker exec ai-agent-sandbox bash -c '
  echo "=== OpenCode Config ===" && \
  cat /home/agentuser/.config/opencode/opencode.json | python3 -m json.tool > /dev/null && echo "Valid JSON" || echo "INVALID JSON"

  echo "=== PI Models Config ===" && \
  cat /home/agentuser/.pi/agent/models.json | python3 -m json.tool > /dev/null && echo "Valid JSON" || echo "INVALID JSON"
'
```

Then restart the container so baked-in configs are picked up on next build, or test interactively:

```bash
docker compose up -d --build   # rebuild with new configs baked in
# OR edit inside a running container and test agents directly
docker exec -it ai-agent-sandbox bash
pi --list-models               # verify PI sees the models
opencode chat                  # verify OpenCode connects
```

## Quick Reference: Model Discovery One-Liners

```bash
# LM Studio — extract model IDs as JSON array
curl -s http://localhost:1234/v1/models | jq '[.data[].id]'

# Ollama — extract model names as JSON array
curl -s http://localhost:11434/api/tags | jq '[.models[].name]'

# vLLM — extract model IDs as JSON array
curl -s http://localhost:8000/v1/models | jq '[.data[].id]'
```

## Notes

- **Model-specific configs** (contextWindow, maxTokens, cost, compat overrides) are not auto-discovered from the API — add them manually based on your knowledge of each model.
- The `/v1/models` endpoint returns only identifiers; it does not expose context window size or other metadata.
- If a provider's `/v1/models` endpoint is unavailable (e.g., Ollama uses `/api/tags`), adapt the discovery command accordingly — the config format remains the same regardless of how you discover models.
- After editing configs locally, rebuild the image (`docker compose up -d --build`) to bake them in, or mount them as volumes for testing.
