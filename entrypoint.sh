#!/bin/sh
# ============================================
# AI Agent Sandbox - Entrypoint Script
# Validates environment, starts optional web terminal,
# then executes agent or interactive shell
# ============================================

set -e

# ======================================================================
# Configuration & Defaults
# ======================================================================

CONTAINER_NAME="ai-agent-sandbox"
WEB_TERMINAL_PORT="${WEB_TERMINAL_PORT:-7681}"
DEFAULT_MODEL="${AGENT_MODEL:-llama3.2}"

# LLM Server defaults (can be overridden via env)
LLM_BASE_URL="${OPENAI_BASE_URL:-http://host.docker.internal:11434/v1}"
LLM_API_KEY="${OPENAI_API_KEY:-ollama}"

# Agent configuration paths (baked into image at build time)
OPENCODE_CONFIG="/home/agentuser/.config/opencode/opencode.json"
PI_MODELS_CONFIG="/home/agentuser/.pi/agent/models.json"

# ======================================================================
# Environment Validation
# ======================================================================

echo "[ENTRYPOINT] Validating environment..."

# Validate required variables are set
if [ -z "$LLM_BASE_URL" ]; then
    echo "[ERROR] OPENAI_BASE_URL is not set. Please configure in .env file."
    exit 1
fi

# Check LLM server connectivity (optional, with timeout)
if command -v curl > /dev/null 2>&1; then
    if ! curl -s --max-time 5 "http://$(echo $LLM_BASE_URL | sed 's|/.*||')" > /dev/null 2>&1; then
        echo "[WARN] LLM server at ${LLM_BASE_URL} appears unreachable"
        echo "[INFO] You may need to configure OPENAI_BASE_URL correctly"
    else
        echo "[OK] LLM server connectivity verified"
    fi
else
    echo "[WARN] curl not available for connection test"
fi

# ======================================================================
# Web Terminal Startup (Optional)
# ======================================================================

if [ "${ENABLE_WEB_TERMINAL:-false}" = "true" ]; then
    echo "[ENTRYPOINT] Starting web terminal on port ${WEB_TERMINAL_PORT}..."
    
    # Check if ttyd is available, install if missing
    if ! command -v ttyd > /dev/null 2>&1; then
        echo "[WARN] ttyd not found. Attempting to start anyway (may fail)..."
    fi
    
    # Start ttyd in background for the container's lifetime
    ttyd --port "${WEB_TERMINAL_PORT}" --allow-remote \
         --title "${CONTAINER_NAME} Web Terminal" /bin/bash &
    
    echo "[OK] Web terminal started on port ${WEB_TERMINAL_PORT}"
    
    # Wait briefly for ttyd to initialize before exec'ing the shell
    sleep 1
fi

# ======================================================================
# Agent Execution or Interactive Shell
# ======================================================================

echo "[ENTRYPOINT] Dropping into interactive mode..."

# Check if any agent-specific command was passed as argument
if [ $# -gt 0 ]; then
    echo "[INFO] Executing: $*"
    exec "$@"
else
    # Default to bash with all environment variables exported for agents
    export LLM_BASE_URL="${LLM_BASE_URL}"
    export LLM_API_KEY="${LLM_API_KEY}"
    
    echo ""
    echo "=============================================="
    echo "  AI Agent Sandbox - Interactive Session"
    echo "=============================================="
    echo ""
    echo "[INFO] OpenAI Base URL: ${LLM_BASE_URL}"
    echo "[INFO] API Key: ${LLM_API_KEY#?} (truncated)"
    echo "[INFO] Default Model: ${DEFAULT_MODEL}"
    echo ""
    echo "[CONFIG] OpenCode:  ${OPENCODE_CONFIG}"
    echo "[CONFIG] PI Models: ${PI_MODELS_CONFIG}"
    echo ""
    echo "=============================================="
    echo "  Available Commands:"
    echo "=============================================="
    echo "  - pi <command>       Run PI coding agent"
    echo "  - opencode <cmd>     Run OpenCode AI agent"  
    echo "  - bash / sh          Interactive shell (default)"
    echo ""
    echo "[TIP] Use 'pi --help' or 'opencode --help' for usage."
    echo "=============================================="
    echo ""
    
    exec bash
fi
