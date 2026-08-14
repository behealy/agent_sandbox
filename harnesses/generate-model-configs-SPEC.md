# Plan: Auto-Generate Model Configs for pi-agent and opencode from llama-server

## Overview

This script will query a running `llama-server` instance via its `/v1/models` endpoint, extract model metadata, and generate two configuration files:

1. **`~/.pi/agent/models.json`** — pi-agent custom provider configuration
2. **`~/.config/opencode/opencode.json`** — opencode global configuration

The script will be idempotent and can be re-run whenever models are added or removed from the llama-server.

---

## Background & Research

### llama-server API

The llama-server router exposes a `/v1/models` (and `/models`) endpoint that returns an OpenAI-compatible model list. Each model entry contains rich metadata:

| Field | Description |
|-------|-------------|
| `id` | Model identifier (preset name, e.g., `"Laguna-S-2.1-Q8_K_XL"`) |
| `aliases` | Array of alternative names (e.g., `["laguna-s-2.1-UD-Q8_K_XL"]`) |
| `status.value` | `"loaded"` or `"unloaded"` |
| `status.args` | Command-line args used to start the model (includes `--ctx-size`, `--reasoning`, `--reasoning-format`, `--temperature`, etc.) |
| `preset` | INI-style preset configuration string |
| `architecture.input_modalities` | `["text"]` or `["text", "image"]` (vision support) |
| `architecture.output_modalities` | `["text"]` |
| `meta` | Only present for **loaded** models; contains `n_ctx`, `n_ctx_train`, `n_params`, `ftype`, `size`, etc. |
| `source` | `"preset"` for preset-based models |

**Key insight:** Context window size is available from two sources:
1. `meta.n_ctx` — only for loaded models (actual runtime context)
2. `--ctx-size` in `status.args` — explicit override for all models
3. If neither is present, the model uses its native context window (not queryable for unloaded models)

**Key insight:** Reasoning support is indicated by `--reasoning on` or `--reasoning-format deepseek` in `status.args`.

**Key insight:** Vision support is indicated by `"image"` in `architecture.input_modalities`.

### pi-agent Config Format (`models.json`)

pi-agent uses `~/.pi/agent/models.json` for custom provider configuration. The format is documented in [pi docs: models.md](docs/models.md).

```json
{
  "providers": {
    "riprouter": {
      "baseUrl": "http://localhost:8080/v1",
      "api": "openai-completions",
      "apiKey": "llama",
      "models": [
        {
          "id": "Qwen3.6-27B",
          "name": "Qwen3.6 27B (Local)",
          "reasoning": false,
          "input": ["text"],
          "contextWindow": 128000,
          "maxTokens": 128000,
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
        }
      ]
    }
  }
}
```

**pi-agent field mapping:**

| llama-server field | pi-agent field | Notes |
|---|---|---|
| `id` | `id` | Model identifier |
| `aliases[0]` | `name` | Human-readable label; falls back to `id` |
| `architecture.input_modalities` contains `"image"` | `input: ["text", "image"]` | Vision support |
| `--reasoning on` or `--reasoning-format deepseek` | `reasoning: true` | Extended thinking support |
| `--reasoning-format deepseek` | `compat.thinkingFormat: "deepseek"` | Thinking parameter format |
| `--ctx-size` or `meta.n_ctx` | `contextWindow` | Context window in tokens |
| `--ctx-size` or `meta.n_ctx` | `maxTokens` | Max output tokens (`contextWindow / 2`) |
| `--ctx-size` absent, model unloaded | `contextWindow: 128000` (default) | Fallback for unknown native context |

### opencode Config Format (`opencode.json`)

opencode uses `~/.config/opencode/opencode.json` for global configuration. The provider config uses the `@ai-sdk/openai-compatible` npm package.

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "llama.cpp": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "llama-server (local)",
      "options": {
        "baseURL": "http://127.0.0.1:8080/v1"
      },
      "models": {
        "qwen3-coder:a3b": {
          "name": "Qwen3-Coder: a3b-30b (local)",
          "limit": {
            "context": 128000,
            "output": 65536
          }
        }
      }
    }
  }
}
```

**opencode field mapping:**

| llama-server field | opencode field | Notes |
|---|---|---|
| `id` | model key | Used as the model identifier |
| `aliases[0]` | `name` | Display name; falls back to `id` |
| `--ctx-size` or `meta.n_ctx` | `limit.context` | Context window in tokens |
| `--ctx-size` or `meta.n_ctx` | `limit.output` | Max output tokens (typically half of context) |
| N/A | N/A | opencode does not have reasoning/vision fields in model config |

---

## Script Design

### Language & Dependencies

- **Language:** Python 3 (available on the system, good JSON/HTTP support)
- **Dependencies:** Only standard library (`urllib.request`, `json`, `os`, `sys`, `argparse`)
- **No external packages required**

### Configuration

The script will accept the following command-line arguments:

| Argument | Default | Description |
|---|---|---|
| `--server-url` | `http://127.0.0.1:8080` | llama-server base URL |
| `--api-key` | `llama` | API key for the llama-server (if configured) |
| `--pi-models-path` | `~/.pi/agent/models.json` | Output path for pi-agent config |
| `--opencode-config-path` | `~/.config/opencode/opencode.json` | Output path for opencode config |
| `--provider-name` | `llama.cpp` | Provider name for opencode config |
| `--pi-provider-name` | `riprouter` | Provider name for pi-agent config |
| `--default-context` | `128000` | Fallback context window for models without explicit ctx-size |
| `--dry-run` | `false` | Print generated configs without writing files |
| `--verbose` | `false` | Print detailed extraction info for each model |

### Algorithm

```
1. Fetch models from llama-server /v1/models endpoint
2. For each model in the response:
   a. Extract id, aliases, status, architecture, meta, preset, args
   b. Determine context window:
      - Check --ctx-size in args (highest priority)
      - Check meta.n_ctx (if loaded)
      - Fall back to --default-context
   c. Determine max output tokens:
      - Use context window / 2 (reasonable default for local models)
      - Or use --ctx-size if it represents total context
   d. Determine reasoning support:
      - Check for --reasoning on in args
      - Check for --reasoning-format deepseek in args
   e. Determine vision support:
      - Check if "image" is in architecture.input_modalities
   f. Determine model name:
      - Use aliases[0] if available
      - Fall back to id
3. Generate pi-agent models.json:
   - Create provider entry with baseUrl, api, apiKey, models array
   - Each model entry includes: id, name, input, reasoning, contextWindow, maxTokens, cost, compat (if reasoning)
4. Generate opencode opencode.json:
   - Create provider entry with npm, name, options.baseURL, models dict
   - Each model entry includes: name, limit.context, limit.output
5. Write both config files (unless --dry-run)
```

### Detailed Field Extraction Logic

#### Context Window Extraction

```python
def extract_context_window(model):
    args = model.get('status', {}).get('args', [])
    preset = model.get('preset', '')
    meta = model.get('meta', {})
    
    # Priority 1: --ctx-size in args
    for i, arg in enumerate(args):
        if arg == '--ctx-size' and i + 1 < len(args):
            return int(args[i + 1])
        elif arg.startswith('--ctx-size='):
            return int(arg.split('=')[1])
    
    # Priority 2: ctx-size in preset
    for line in preset.split('\n'):
        line = line.strip()
        if line.startswith('ctx-size') or line.startswith('c '):
            return int(line.split('=')[1].strip())
    
    # Priority 3: meta.n_ctx (loaded models only)
    if meta and meta.get('n_ctx'):
        return int(meta['n_ctx'])
    
    # Priority 4: meta.n_ctx_train (native context)
    if meta and meta.get('n_ctx_train'):
        return int(meta['n_ctx_train'])
    
    # Priority 5: default
    return DEFAULT_CONTEXT
```

#### Reasoning Support Extraction

```python
def extract_reasoning(model):
    args = model.get('status', {}).get('args', [])
    preset = model.get('preset', '')
    
    # Check for --reasoning on in args
    for i, arg in enumerate(args):
        if arg == '--reasoning' and i + 1 < len(args):
            if args[i + 1].lower() == 'on':
                return True
        elif arg.startswith('--reasoning='):
            if arg.split('=')[1].lower() == 'on':
                return True
    
    # Check preset for reasoning = on
    for line in preset.split('\n'):
        if line.strip().startswith('reasoning') and '=' in line:
            value = line.split('=')[1].strip().lower()
            if value == 'on':
                return True
    
    return False

def extract_thinking_format(model):
    args = model.get('status', {}).get('args', [])
    preset = model.get('preset', '')
    
    # Check for --reasoning-format in args
    for i, arg in enumerate(args):
        if arg == '--reasoning-format' and i + 1 < len(args):
            return args[i + 1]
        elif arg.startswith('--reasoning-format='):
            return arg.split('=')[1]
    
    # Check preset for reasoning-format
    for line in preset.split('\n'):
        if line.strip().startswith('reasoning-format') and '=' in line:
            return line.split('=')[1].strip()
    
    return None
```

#### Vision Support Extraction

```python
def extract_vision(model):
    modalities = model.get('architecture', {}).get('input_modalities', [])
    return 'image' in modalities
```

#### Model Name Extraction

```python
def extract_model_name(model):
    aliases = model.get('aliases', [])
    if aliases:
        return aliases[0]
    return model.get('id', 'unknown')
```

### Generated Config Examples

#### pi-agent models.json (generated)

```json
{
  "providers": {
    "riprouter": {
      "baseUrl": "http://localhost:8080/v1",
      "api": "openai-completions",
      "apiKey": "llama",
      "models": [
        {
          "id": "DeepSeek-V4-Flash",
          "name": "deepseek-v4-flash-UD-Q4_K_XL",
          "reasoning": true,
          "input": ["text"],
          "contextWindow": 131072,
          "maxTokens": 65536,
          "compat": {
            "thinkingFormat": "deepseek"
          }
        },
        {
          "id": "Gemma-4-31B-IT",
          "name": "gemma-4-31b-it-qat-UD-Q4_K_XL",
          "input": ["text", "image"],
          "contextWindow": 128000,
          "maxTokens": 64000
        },
        {
          "id": "Laguna-S-2.1-Q8_K_XL",
          "name": "laguna-s-2.1-UD-Q8_K_XL",
          "input": ["text"],
          "contextWindow": 196608,
          "maxTokens": 98304
        }
      ]
    }
  }
}
```

#### opencode opencode.json (generated)

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "llama.cpp": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "llama-server (local)",
      "options": {
        "baseURL": "http://127.0.0.1:8080/v1"
      },
      "models": {
        "DeepSeek-V4-Flash": {
          "name": "deepseek-v4-flash-UD-Q4_K_XL",
          "limit": {
            "context": 131072,
            "output": 65536
          }
        },
        "Gemma-4-31B-IT": {
          "name": "gemma-4-31b-it-qat-UD-Q4_K_XL",
          "limit": {
            "context": 128000,
            "output": 64000
          }
        },
        "Laguna-S-2.1-Q8_K_XL": {
          "name": "laguna-s-2.1-UD-Q8_K_XL",
          "limit": {
            "context": 196608,
            "output": 98304
          }
        }
      }
    }
  }
}
```

### Output Behavior

- **pi-agent config:** Written to `~/.pi/agent/models.json`. If the file exists, the script reads it, replaces the provider entry matching the configured provider name (default `riprouter`), and preserves all other providers. If the file doesn't exist, creates it with just the new provider.
- **opencode config:** Written to `~/.config/opencode/opencode.json`. If the file exists, the script reads it, updates only the `provider[provider-name]` entry (default `llama.cpp`), and preserves all other config keys (e.g., `model`, `autoupdate`, `permission`, etc.). If the file doesn't exist, creates it with the schema, provider entry, and any additional top-level keys from CLI args.
- **Directory creation:** If output directories don't exist (e.g., `~/.config/opencode/`), they are created automatically.
- **Backup:** Before overwriting, existing files are backed up to `.bak` extension (only if the file exists and will be modified).
- **Verbose mode:** Prints each model's extracted metadata for verification
- **Dry run:** Prints both generated configs to stdout without writing
- **Model names:** Use `aliases[0]` if available, otherwise `id`. No formatting applied.
- **Cost field:** Omitted from pi-agent model entries (local models are free).
- **Default model:** The `model` field in opencode.json is left unset (user selects via CLI or TUI).

### Error Handling

- If llama-server is unreachable: Print error message and exit with code 1
- If `/v1/models` returns non-200: Print error with status code and exit with code 1
- If response JSON is malformed: Print error and exit with code 1
- If output directory doesn't exist: Create it (e.g., `~/.config/opencode/`)
- If output file exists: Back it up to `.bak` before overwriting

---

## File Structure

```
/home/brendan/llama/
├── script-plan.md          ← This document
├── generate-model-configs.py  ← The script (to be created after review)
├── model-presets.ini       ← Existing llama.cpp presets (reference)
├── models/                 ← Local GGUF model files
└── builds/                 ← llama-server builds
```

---

## Usage Examples

```bash
# Generate configs with defaults (queries http://127.0.0.1:8080)
python3 generate-model-configs.py

# Specify a custom server URL and API key
python3 generate-model-configs.py --server-url http://127.0.0.1:9090 --api-key my-secret

# Dry run to preview output
python3 generate-model-configs.py --dry-run --verbose

# Custom output paths
python3 generate-model-configs.py \
  --pi-models-path ./pi-models.json \
  --opencode-config-path ./opencode.json

# Use a different default context window
python3 generate-model-configs.py --default-context 262144
```

---

## Decisions (Answered)

1. **Max output tokens:** Use `contextWindow / 2` for both pi-agent (`maxTokens`) and opencode (`limit.output`). This is a reasonable default for local models.

2. **Provider names:** Make configurable via CLI args. pi-agent defaults to `riprouter` (matching existing config), opencode defaults to `llama.cpp` (matching the example). Both can be overridden.

3. **Config merging:**
   - **pi-agent:** Overwrite the provider entry by name (e.g., `riprouter`), but preserve all other providers in the existing `models.json`.
   - **opencode:** Deep-merge with existing `opencode.json`, preserving all settings outside the `provider` key. Within `provider`, only update the llama.cpp provider entry.

4. **Model filtering:** Include all models (loaded and unloaded). This makes the config complete regardless of current server state.

5. **Reasoning for opencode:** Omit entirely. opencode's model config schema does not support reasoning or compat fields. Reasoning support is only noted in the pi-agent config.

6. **Output token limits:** Same as #1 — `contextWindow / 2` for both configs.

---

## Implementation Status: ✅ COMPLETE

The script has been implemented as `generate-model-configs.py` and tested against the running llama-server. All features work correctly:

- ✅ Queries llama-server `/v1/models` endpoint
- ✅ Extracts model metadata (id, aliases, context window, reasoning, vision)
- ✅ Generates pi-agent `models.json` with proper field mapping
- ✅ Generates opencode `opencode.json` with proper field mapping
- ✅ Config merging (preserves existing providers/settings)
- ✅ Backup of existing files before overwriting
- ✅ CLI arguments (server-url, api-key, paths, provider names, defaults)
- ✅ Verbose and dry-run modes
- ✅ Directory creation for missing paths

### Test Results

- **9 models** extracted from the running llama-server
- **Config merging verified** for both pi-agent (multiple providers preserved) and opencode (model, autoupdate, permission settings preserved)
- **Backup verified** — existing files backed up to `.bak` before overwriting
- **Dry-run verified** — configs printed to stdout without writing
- **Verbose mode verified** — extraction details printed for each model

### Usage

```bash
# Generate configs with defaults
python3 generate-model-configs.py

# Dry run with verbose output
python3 generate-model-configs.py --dry-run --verbose

# Custom server URL and output paths
python3 generate-model-configs.py --server-url http://127.0.0.1:9090 --pi-models-path ./pi-models.json
```