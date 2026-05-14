---
title: Providers
description: Using any LLM provider in OpenCode.
---

import config from "../../../config.mjs"
export const console = config.console

OpenCode uses the [AI SDK](https://ai-sdk.dev/) and [Models.dev](https://models.dev) to support **75+ LLM providers** and it supports running local models.

To add a provider you need to:

1. Add the API keys for the provider using the `/connect` command.
2. Configure the provider in your OpenCode config.

---

### Credentials

When you add a provider's API keys with the `/connect` command, they are stored
in `~/.local/share/opencode/auth.json`.

---

### Config

You can customize the providers through the `provider` section in your OpenCode
config.

---

#### Base URL

You can customize the base URL for any provider by setting the `baseURL` option. This is useful when using proxy services or custom endpoints.

```json title="opencode.json" {6}
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "anthropic": {
      "options": {
        "baseURL": "https://api.anthropic.com/v1"
      }
    }
  }
}
```

---

## OpenCode Zen

OpenCode Zen is a list of models provided by the OpenCode team that have been
tested and verified to work well with OpenCode. [Learn more](/docs/zen).

:::tip
If you are new, we recommend starting with OpenCode Zen.
:::

1. Run the `/connect` command in the TUI, select `OpenCode Zen`, and head to [opencode.ai/auth](https://opencode.ai/zen).

   ```txt
   /connect
   ```

2. Sign in, add your billing details, and copy your API key.

3. Paste your API key.

   ```txt
   ┌ API key
   │
   │
   └ enter
   ```

4. Run `/models` in the TUI to see the list of models we recommend.

   ```txt
   /models
   ```

It works like any other provider in OpenCode and is completely optional to use.

---

## OpenCode Go

OpenCode Go is a low cost subscription plan that provides reliable access to popular open coding models provided by the OpenCode team that have been
tested and verified to work well with OpenCode.

1. Run the `/connect` command in the TUI, select `OpenCode Go`, and head to [opencode.ai/auth](https://opencode.ai/zen).

   ```txt
   /connect
   ```

2. Sign in, add your billing details, and copy your API key.

3. Paste your API key.

   ```txt
   ┌ API key
   │
   │
   └ enter
   ```

4. Run `/models` in the TUI to see the list of models we recommend.

   ```txt
   /models
   ```

It works like any other provider in OpenCode and is completely optional to use.

---

## Directory

Let's look at some of the providers in detail. If you'd like to add a provider to the
list, feel free to open a PR.

---

### GitLab Duo

:::caution[Experimental]
GitLab Duo support in OpenCode is experimental. Features, configuration, and
behavior may change in future releases.
:::

OpenCode integrates with the [GitLab Duo Agent Platform](https://docs.gitlab.com/user/duo_agent_platform/),
providing AI-powered agentic chat with native tool calling capabilities.

:::note[License requirements]
GitLab Duo Agent Platform requires a **Premium** or **Ultimate** GitLab
subscription. It is available on GitLab.com and GitLab Self-Managed.
See [GitLab Duo Agent Platform prerequisites](https://docs.gitlab.com/user/duo_agent_platform/#prerequisites)
for full requirements.
:::

1. Run the `/connect` command and select GitLab.

   ```txt
   /connect
   ```

2. Choose your authentication method:

   ```txt
   ┌ Select auth method
   │
   │ OAuth (Recommended)
   │ Personal Access Token
   └
   ```

   #### Using OAuth (Recommended)

   Select **OAuth** and your browser will open for authorization.

   #### Using Personal Access Token
   1. Go to [GitLab User Settings > Access Tokens](https://gitlab.com/-/user_settings/personal_access_tokens)
   2. Click **Add new token**
   3. Name: `OpenCode`, Scopes: `api`
   4. Copy the token (starts with `glpat-`)
   5. Enter it in the terminal

3. Run the `/models` command to see available models.

   ```txt
   /models
   ```

   Three Claude-based models are available:
   - **duo-chat-haiku-4-5** (Default) - Fast responses for quick tasks
   - **duo-chat-sonnet-4-5** - Balanced performance for most workflows
   - **duo-chat-opus-4-5** - Most capable for complex analysis

:::note
You can also specify 'GITLAB_TOKEN' environment variable if you don't want
to store token in opencode auth storage.
:::

##### Self-Hosted GitLab

:::note[compliance note]
OpenCode uses a small model for some AI tasks like generating the session title.
It is configured to use gpt-5-nano by default, hosted by Zen. To lock OpenCode
to only use your own GitLab-hosted instance, add the following to your
`opencode.json` file. It is also recommended to disable session sharing.

```json
{
  "$schema": "https://opencode.ai/config.json",
  "small_model": "gitlab/duo-chat-haiku-4-5",
  "share": "disabled"
}
```

:::

For self-hosted GitLab instances:

```bash
export GITLAB_INSTANCE_URL=https://gitlab.company.com
export GITLAB_TOKEN=glpat-...
```

If your instance runs a custom AI Gateway:

```bash
GITLAB_AI_GATEWAY_URL=https://ai-gateway.company.com
```

Or add to your bash profile:

```bash title="~/.bash_profile"
export GITLAB_INSTANCE_URL=https://gitlab.company.com
export GITLAB_AI_GATEWAY_URL=https://ai-gateway.company.com
export GITLAB_TOKEN=glpat-...
```

:::note
Your GitLab administrator must:

1. [Turn on GitLab Duo](https://docs.gitlab.com/user/duo_agent_platform/turn_on_off/#turn-gitlab-duo-on-or-off)
   for the user, group, or instance
2. [Turn on the Agent Platform](https://docs.gitlab.com/user/duo_agent_platform/turn_on_off/#turn-gitlab-duo-agent-platform-on-or-off)
   (GitLab 18.8+) or [enable beta and experimental features](https://docs.gitlab.com/user/duo_agent_platform/turn_on_off/#turn-on-beta-and-experimental-features)
   (GitLab 18.7 and earlier)
3. For Self-Managed, [configure your instance](https://docs.gitlab.com/administration/gitlab_duo/configure/gitlab_self_managed/)
   :::

##### OAuth for Self-Hosted instances

In order to make Oauth working for your self-hosted instance, you need to create
a new application (Settings → Applications) with the
callback URL `http://127.0.0.1:8080/callback` and following scopes:

- api (Access the API on your behalf)
- read_user (Read your personal information)
- read_repository (Allows read-only access to the repository)

Then expose application ID as environment variable:

```bash
export GITLAB_OAUTH_CLIENT_ID=your_application_id_here
```

More documentation on [opencode-gitlab-auth](https://www.npmjs.com/package/opencode-gitlab-auth) homepage.

##### Configuration

Customize through `opencode.json`:

```json title="opencode.json"
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "gitlab": {
      "options": {
        "instanceUrl": "https://gitlab.com"
      }
    }
  }
}
```

##### GitLab Duo Agent Platform (DAP) Workflow Models

DAP workflow models provide an alternative execution path that routes tool calls
through GitLab's Duo Workflow Service (DWS) instead of the standard agentic chat.
When a `duo-workflow-*` model is selected, OpenCode will:

1. Discover available models from your GitLab namespace
2. Present a selection picker if multiple models are available
3. Cache the selected model to disk for fast subsequent startups
4. Route tool execution requests through OpenCode's permission-gated tool system

Available DAP workflow models follow the `duo-workflow-*` naming convention and
are dynamically discovered from your GitLab instance.

##### GitLab API Tools (Optional, but highly recommended)

To access GitLab tools (merge requests, issues, pipelines, CI/CD, etc.):

```json title="opencode.json"
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["opencode-gitlab-plugin"]
}
```

This plugin provides comprehensive GitLab repository management capabilities including MR reviews, issue tracking, pipeline monitoring, and more.

---

### Hugging Face

[Hugging Face Inference Providers](https://huggingface.co/docs/inference-providers) provides access to open models supported by 17+ providers.

1. Head over to [Hugging Face settings](https://huggingface.co/settings/tokens/new?ownUserPermissions=inference.serverless.write&tokenType=fineGrained) to create a token with permission to make calls to Inference Providers.

2. Run the `/connect` command and search for **Hugging Face**.

   ```txt
   /connect
   ```

3. Enter your Hugging Face token.

   ```txt
   ┌ API key
   │
   │
   └ enter
   ```

4. Run the `/models` command to select a model like _Kimi-K2-Instruct_ or _GLM-4.6_.

   ```txt
   /models
   ```

---

### llama.cpp

You can configure opencode to use local models through [llama.cpp's](https://github.com/ggml-org/llama.cpp) llama-server utility

```json title="opencode.json" "llama.cpp" {5, 6, 8, 10-15}
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

In this example:

- `llama.cpp` is the custom provider ID. This can be any string you want.
- `npm` specifies the package to use for this provider. Here, `@ai-sdk/openai-compatible` is used for any OpenAI-compatible API.
- `name` is the display name for the provider in the UI.
- `options.baseURL` is the endpoint for the local server.
- `models` is a map of model IDs to their configurations. The model name will be displayed in the model selection list.

---

### IO.NET

IO.NET offers 17 models optimized for various use cases:

1. Head over to the [IO.NET console](https://ai.io.net/), create an account, and generate an API key.

2. Run the `/connect` command and search for **IO.NET**.

   ```txt
   /connect
   ```

3. Enter your IO.NET API key.

   ```txt
   ┌ API key
   │
   │
   └ enter
   ```

4. Run the `/models` command to select a model.

   ```txt
   /models
   ```

---

### LM Studio

You can configure opencode to use local models through LM Studio.

```json title="opencode.json" "lmstudio" {5, 6, 8, 10-14}
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "lmstudio": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "LM Studio (local)",
      "options": {
        "baseURL": "http://127.0.0.1:1234/v1"
      },
      "models": {
        "google/gemma-3n-e4b": {
          "name": "Gemma 3n-e4b (local)"
        }
      }
    }
  }
}
```

In this example:

- `lmstudio` is the custom provider ID. This can be any string you want.
- `npm` specifies the package to use for this provider. Here, `@ai-sdk/openai-compatible` is used for any OpenAI-compatible API.
- `name` is the display name for the provider in the UI.
- `options.baseURL` is the endpoint for the local server.
- `models` is a map of model IDs to their configurations. The model name will be displayed in the model selection list.

---

### Moonshot AI

To use Kimi K2 from Moonshot AI:

1. Head over to the [Moonshot AI console](https://platform.moonshot.ai/console), create an account, and click **Create API key**.

2. Run the `/connect` command and search for **Moonshot AI**.

   ```txt
   /connect
   ```

3. Enter your Moonshot API key.

   ```txt
   ┌ API key
   │
   │
   └ enter
   ```

4. Run the `/models` command to select _Kimi K2_.

   ```txt
   /models
   ```

---

### MiniMax

1. Head over to the [MiniMax API Console](https://platform.minimax.io/login), create an account, and generate an API key.

2. Run the `/connect` command and search for **MiniMax**.

   ```txt
   /connect
   ```

3. Enter your MiniMax API key.

   ```txt
   ┌ API key
   │
   │
   └ enter
   ```

4. Run the `/models` command to select a model like _M2.1_.

   ```txt
   /models
   ```

---

### Ollama

You can configure opencode to use local models through Ollama.

:::tip
Ollama can automatically configure itself for OpenCode. See the [Ollama integration docs](https://docs.ollama.com/integrations/opencode) for details.
:::

```json title="opencode.json" "ollama" {5, 6, 8, 10-14}
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (local)",
      "options": {
        "baseURL": "http://localhost:11434/v1"
      },
      "models": {
        "llama2": {
          "name": "Llama 2"
        }
      }
    }
  }
}
```

In this example:

- `ollama` is the custom provider ID. This can be any string you want.
- `npm` specifies the package to use for this provider. Here, `@ai-sdk/openai-compatible` is used for any OpenAI-compatible API.
- `name` is the display name for the provider in the UI.
- `options.baseURL` is the endpoint for the local server.
- `models` is a map of model IDs to their configurations. The model name will be displayed in the model selection list.

:::tip
If tool calls aren't working, try increasing `num_ctx` in Ollama. Start around 16k - 32k.
:::

---

### Ollama Cloud

To use Ollama Cloud with OpenCode:

1. Head over to [https://ollama.com/](https://ollama.com/) and sign in or create an account.

2. Navigate to **Settings** > **Keys** and click **Add API Key** to generate a new API key.

3. Copy the API key for use in OpenCode.

4. Run the `/connect` command and search for **Ollama Cloud**.

   ```txt
   /connect
   ```

5. Enter your Ollama Cloud API key.

   ```txt
   ┌ API key
   │
   │
   └ enter
   ```

6. **Important**: Before using cloud models in OpenCode, you must pull the model information locally:

   ```bash
   ollama pull gpt-oss:20b-cloud
   ```

7. Run the `/models` command to select your Ollama Cloud model.

   ```txt
   /models
   ```

---

### OpenCode Zen

OpenCode Zen is a list of tested and verified models provided by the OpenCode team. [Learn more](/docs/zen).

1. Sign in to **<a href={console}>OpenCode Zen</a>** and click **Create API Key**.

2. Run the `/connect` command and search for **OpenCode Zen**.

   ```txt
   /connect
   ```

3. Enter your OpenCode API key.

   ```txt
   ┌ API key
   │
   │
   └ enter
   ```

4. Run the `/models` command to select a model like _Qwen 3 Coder 480B_.

   ```txt
   /models
   ```

---

### OpenRouter

1. Head over to the [OpenRouter dashboard](https://openrouter.ai/settings/keys), click **Create API Key**, and copy the key.

2. Run the `/connect` command and search for OpenRouter.

   ```txt
   /connect
   ```

3. Enter the API key for the provider.

   ```txt
   ┌ API key
   │
   │
   └ enter
   ```

4. Many OpenRouter models are preloaded by default, run the `/models` command to select the one you want.

   ```txt
   /models
   ```

   You can also add additional models through your opencode config.

   ```json title="opencode.json" {6}
   {
     "$schema": "https://opencode.ai/config.json",
     "provider": {
       "openrouter": {
         "models": {
           "somecoolnewmodel": {}
         }
       }
     }
   }
   ```

5. You can also customize them through your opencode config. Here's an example of specifying a provider

   ```json title="opencode.json"
   {
     "$schema": "https://opencode.ai/config.json",
     "provider": {
       "openrouter": {
         "models": {
           "moonshotai/kimi-k2": {
             "options": {
               "provider": {
                 "order": ["baseten"],
                 "allow_fallbacks": false
               }
             }
           }
         }
       }
     }
   }
   ```

---

### LLM Gateway

1. Head over to the [LLM Gateway dashboard](https://llmgateway.io/dashboard), click **Create API Key**, and copy the key.

2. Run the `/connect` command and search for LLM Gateway.

   ```txt
   /connect
   ```

3. Enter the API key for the provider.

   ```txt
   ┌ API key
   │
   │
   └ enter
   ```

4. Many LLM Gateway models are preloaded by default, run the `/models` command to select the one you want.

   ```txt
   /models
   ```

   You can also add additional models through your opencode config.

   ```json title="opencode.json" {6}
   {
     "$schema": "https://opencode.ai/config.json",
     "provider": {
       "llmgateway": {
         "models": {
           "somecoolnewmodel": {}
         }
       }
     }
   }
   ```

5. You can also customize them through your opencode config. Here's an example of specifying a provider

   ```json title="opencode.json"
   {
     "$schema": "https://opencode.ai/config.json",
     "provider": {
       "llmgateway": {
         "models": {
           "glm-4.7": {
             "name": "GLM 4.7"
           },
           "gpt-5.2": {
             "name": "GPT-5.2"
           },
           "gemini-2.5-pro": {
             "name": "Gemini 2.5 Pro"
           },
           "claude-3-5-sonnet-20241022": {
             "name": "Claude 3.5 Sonnet"
           }
         }
       }
     }
   }
   ```
---

## Custom provider

To add any **OpenAI-compatible** provider that's not listed in the `/connect` command:

:::tip
You can use any OpenAI-compatible provider with opencode. Most modern AI providers offer OpenAI-compatible APIs.
:::

1. Run the `/connect` command and scroll down to **Other**.

   ```bash
   $ /connect

   ┌  Add credential
   │
   ◆  Select provider
   │  ...
   │  ● Other
   └
   ```

2. Enter a unique ID for the provider.

   ```bash
   $ /connect

   ┌  Add credential
   │
   ◇  Enter provider id
   │  myprovider
   └
   ```

   :::note
   Choose a memorable ID, you'll use this in your config file.
   :::

3. Enter your API key for the provider.

   ```bash
   $ /connect

   ┌  Add credential
   │
   ▲  This only stores a credential for myprovider - you will need to configure it in opencode.json, check the docs for examples.
   │
   ◇  Enter your API key
   │  sk-...
   └
   ```

4. Create or update your `opencode.json` file in your project directory:

   ```json title="opencode.json" ""myprovider"" {5-15}
   {
     "$schema": "https://opencode.ai/config.json",
     "provider": {
       "myprovider": {
         "npm": "@ai-sdk/openai-compatible",
         "name": "My AI ProviderDisplay Name",
         "options": {
           "baseURL": "https://api.myprovider.com/v1"
         },
         "models": {
           "my-model-name": {
             "name": "My Model Display Name"
           }
         }
       }
     }
   }
   ```

   Here are the configuration options:
   - **npm**: AI SDK package to use, `@ai-sdk/openai-compatible` for OpenAI-compatible providers (for `/v1/chat/completions`). If your provider/model uses `/v1/responses`, use `@ai-sdk/openai`.
   - **name**: Display name in UI.
   - **models**: Available models.
   - **options.baseURL**: API endpoint URL.
   - **options.apiKey**: Optionally set the API key, if not using auth.
   - **options.headers**: Optionally set custom headers.

   More on the advanced options in the example below.

5. Run the `/models` command and your custom provider and models will appear in the selection list.

---

##### Example

Here's an example setting the `apiKey`, `headers`, and model `limit` options.

```json title="opencode.json" {9,11,17-20}
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "myprovider": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "My AI ProviderDisplay Name",
      "options": {
        "baseURL": "https://api.myprovider.com/v1",
        "apiKey": "{env:ANTHROPIC_API_KEY}",
        "headers": {
          "Authorization": "Bearer custom-token"
        }
      },
      "models": {
        "my-model-name": {
          "name": "My Model Display Name",
          "limit": {
            "context": 200000,
            "output": 65536
          }
        }
      }
    }
  }
}
```

Configuration details:

- **apiKey**: Set using `env` variable syntax, [learn more](/docs/config#env-vars).
- **headers**: Custom headers sent with each request.
- **limit.context**: Maximum input tokens the model accepts.
- **limit.output**: Maximum tokens the model can generate.

The `limit` fields allow OpenCode to understand how much context you have left. Standard providers pull these from models.dev automatically.

---

## Troubleshooting

If you are having trouble with configuring a provider, check the following:

1. **Check the auth setup**: Run `opencode auth list` to see if the credentials
   for the provider are added to your config.

   This doesn't apply to providers like Amazon Bedrock, that rely on environment variables for their auth.

2. For custom providers, check the opencode config and:
   - Make sure the provider ID used in the `/connect` command matches the ID in your opencode config.
   - The right npm package is used for the provider. For example, use `@ai-sdk/cerebras` for Cerebras. And for all other OpenAI-compatible providers, use `@ai-sdk/openai-compatible` (for `/v1/chat/completions`); if a model uses `/v1/responses`, use `@ai-sdk/openai`. For mixed setups under one provider, you can override per model via `provider.npm`.
   - Check correct API endpoint is used in the `options.baseURL` field.