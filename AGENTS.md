# 🐳 Docker AI Agent Sandbox (PI + OpenCode)

Production-ready, isolated container environment for running both [@earendil-works/pi-coding-agent](https://github.com/earendil-works/pi-coding-agent) and [opencode-ai](https://github.com/opencode-ai/coding-agent) with configs baked into the image at build time.

---

## 📋 Features

| Feature | Description |
|---------|-------------|
| **Non-root runtime** | Container runs as `agentuser` (UID 1000), not root |
| **Baked-in configs** | OpenCode & PI model configurations baked at build time, no volume mounts needed |
| **OpenAI-compatible LLM** | Connects to local servers via REST API (Ollama, LM Studio, vLLM, etc.) |
| **Resource limits** | CPU/memory constraints enforced via Docker Compose deploy |
| **Secure networking** | Custom bridge network with host connectivity via `host.docker.internal` |
| **Optional web terminal** | Lightweight ttyd UI on port 7681 when enabled |
| **Minimal image size** | <400MB target using node:20-bookworm-slim base |

---

## 🛠️ Quick Start

### Prerequisites

- Docker Engine 20.10+ or Podman with equivalent networking support
- Node.js knowledge (for troubleshooting agent usage)
- Local LLM server running and accessible (Ollama, LM Studio, vLLM, etc.)

### Build the Image

```bash
# Build the sandbox image (~500MB initial download, ~200-300MB final size)
docker compose build --no-cache

# Verify image was built successfully
docker images | grep agent-sandbox
```

**First-time note:** Initial build may take 5-10 minutes as it downloads Node.js base image (~600MB), npm packages, and cleans up. Subsequent builds are ~10 seconds with no changes.

### Run the Container

```bash
# Copy environment template and configure
cp .env.example .env

# Edit .env to point your LLM server:
# OPENAI_BASE_URL=http://host.docker.internal:11434/v1  # Ollama default
# OPENAI_API_KEY=ollama                                 # or empty string for most local servers

# Start the sandbox (non-interactive mode)
docker compose up -d

# Check logs
docker logs -f ai-agent-sandbox
```

### Interactive Access

**Option 1: CLI Terminal (Recommended)**
```bash
# Enter interactive shell with pre-configured environment
docker exec -it ai-agent-sandbox bash

# Or run PI agent directly
docker exec -it ai-agent-sandbox pi --help

# Or run OpenCode agent
docker exec -it ai-agent-sandbox opencode --help
```

**Option 2: Web Terminal (Optional)**
```bash
# Enable web terminal in .env: ENABLE_WEB_TERMINAL=true
# Start container and access browser UI at port 7681
docker compose up -d

# Open your browser to: http://<host-ip>:7681
```

---

## 📁 Project Structure

```
ai-agent-sandbox/
├── Dockerfile              # Multi-stage image build (Node.js LTS)
├── docker-compose.yml      # Service definition with security profiles
├── .env.example            # Template environment variables
├── entrypoint.sh           # Startup validation and agent execution
├── opencode-config.json    # OpenCode configuration template (baked in)
├── pi-models.json          # PI agent models configuration (baked in)
└── README.md               # This file
```

---

## 🔧 Configuration Guide

### Environment Variables (.env)

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `OPENAI_BASE_URL` | ✅ Yes | LLM server endpoint (OpenAI format) | `http://host.docker.internal:11434/v1` |
| `OPENAI_API_KEY` | ✅ Yes | API key for LLM server (often "ollama" or empty) | `ollama` |
| `AGENT_MODEL` | ❌ No | Default model name for agents | `llama3.2` |
| `ENABLE_WEB_TERMINAL` | ❌ No | Enable ttyd web UI (`true`/`false`) | `false` |
| `WEB_TERMINAL_PORT` | ❌ No | Port for web terminal | `7681` |
| `VERBOSE` | ❌ No | Verbose startup logging | `true` |

### LLM Server Endpoints by Backend

| Backend | Base URL Pattern | API Key | Context Window |
|---------|------------------|---------|----------------|
| **Ollama** | `http://host.docker.internal:11434/v1` | `ollama` or `` | Varies |
| **LM Studio** | `http://host.docker.internal:1234/v1` | `` (empty) | Varies |
| **vLLM** | `http://localhost:8000/v1` | Your key | 32k-128k+ |
| **llama.cpp** | `http://host.docker.internal:11435/v1` | `` (empty) | Varies |

### Updating Baked-in Configurations

Since configs are baked into the image at build time, to update them:

```bash
# 1. Edit the config files in this directory
nano opencode-config.json
nano pi-models.json

# 2. Rebuild and restart (no need to stop first)
docker compose up -d --build

# Container will automatically use updated configs on startup
```

For **temporary testing** without rebuild:
```bash
# Mount config as volume (only for testing, not recommended for production)
docker run --rm \
  --mount type=bind,source=./opencode-config.json,target=/home/agentuser/.config/opencode/opencode.json \
  ai-agent-sandbox bash
```

---

## 🏃 Usage Examples

### Using the PI Agent

```bash
# Enter container and run PI agent
docker exec -it ai-agent-sandbox bash

# Inside container:
pi init                    # Initialize project structure
pi edit file.ts            # AI-assisted editing
pi explain code.ts         # Get explanation of code
pi --help                  # Show all commands
```

### Using OpenCode Agent

```bash
# Enter container and run OpenCode
docker exec -it ai-agent-sandbox bash

# Inside container:
opencode init              # Initialize workspace
opencode chat             # Chat with AI agent
opencode edit file.js      # Edit code with AI assistance
```

### Batch Operations (Non-interactive)

```bash
# Run PI command without entering shell
docker exec ai-agent-sandbox pi --help

# Run OpenCode command
docker exec ai-agent-sandbox opencode --version
```

---

## 🔒 Security Best Practices

### Container Isolation
- **No privileged mode** (`--privileged` not used)
- **Read-only root filesystem** (except `/tmp`)
- **All capabilities dropped** (`cap_drop: ALL`)
- **Non-root user** at runtime (`agentuser`:1000)
- **No-new-privileges** security option enabled

### Network Security
- Custom bridge network (`agent-net`) - not host mode by default
- No Docker socket mounting (unless explicitly needed)
- Port exposure only when `ENABLE_WEB_TERMINAL=true`

### Resource Constraints
```yaml
# Default limits in docker-compose.yml:
limits:
  cpus: '2.0'          # Max 2 vCPUs
  memory: 4G           # Max 4GB RAM
reservations:
  cpus: '0.5'          # Guaranteed 0.5 vCPUs
  memory: 1G           # Guaranteed 1GB RAM
```

### Recommendations
- **Production**: Use a dedicated LLM server with TLS
- **Development**: Local servers (Ollama, LM Studio) are fine
- **Secrets**: Never commit `.env` to version control - it's in `.gitignore`
- **Updates**: Rebuild when updating agent packages

---

## 🌐 Cross-Platform Networking Guide

### Linux (Docker Engine)

```bash
# Standard Docker 20.10+ uses host.docker.internal natively
OPENAI_BASE_URL=http://host.docker.internal:11434/v1

# Legacy workaround if needed
export HOST_IP=$(hostname -I | awk '{print $1}')
docker run --add-host=host-gateway:host.docker.internal <image>
```

### macOS (Docker Desktop)

```bash
# host.docker.internal works natively on Docker Desktop for Mac
OPENAI_BASE_URL=http://host.docker.internal:11434/v1

# Verify connectivity from inside container:
docker exec ai-agent-sandbox bash -c 'curl -v http://host.docker.internal:11434'
```

### Windows (Docker Desktop)

```bash
# host.docker.internal is supported natively on Docker Desktop for Windows
OPENAI_BASE_URL=http://host.docker.internal:11434/v1

# Alternative: use Windows adapter IP if needed
ipconfig | findstr "IPv4"  # Note your VirtualBox or Hyper-V IPv4 address
```

### Troubleshooting Network Issues

**Problem**: `connection refused` to LLM server

**Solution Steps:**
1. Verify LLM server is running locally: `curl http://localhost:11434/api/tags` (Ollama)
2. Check port accessibility: `netstat -an | grep 11434`
3. Try localhost inside container first: `docker exec ai-agent-sandbox curl http://host.docker.internal:11434`
4. For Docker Desktop, ensure VM networking isn't blocking the port

## 🧪 Validation Checklist

Before considering the setup complete, verify:

- [ ] **Container runs as non-root**: Check `docker exec ai-agent-sandbox id` shows UID 1000
- [ ] **Both agents installed**: Run `pi --version` and `opencode --version` inside container
- [ ] **Config files exist**: Verify paths `/home/agentuser/.config/opencode/opencode.json` and `/home/agentuser/.pi/agent/models.json`
- [ ] **No config volume mounts**: Confirm docker-compose.yml only has workspace volumes, no `~/.config` or `~/.pi` mounts
- [ ] **LLM connectivity works**: Can access endpoint from inside container: `curl http://host.docker.internal:11434`
- [ ] **Image size < 500MB**: Check with `docker images ai-agent-sandbox --format "{{.Size}}"`
- [ ] **Web terminal optional**: Container starts successfully without web terminal enabled
- [ ] **Logs show validation steps**: Startup logs should show environment validation messages

### Quick Validation Script

```bash
# Run this inside the container to verify setup
docker exec ai-agent-sandbox bash -c '
echo "=== User Check ==="
id
echo ""
echo "=== Agent Installation ==="
which pi && which opencode
echo ""
echo "=== Config Files ==="
ls -la /home/agentuser/.config/opencode/opencode.json
ls -la /home/agentuser/.pi/agent/models.json
echo ""
echo "=== LLM Connection Test ==="
curl -s http://host.docker.internal:11434/api/tags || echo "LLM endpoint may be unreachable"
'
```

---

## 🐛 Troubleshooting

### Agent Not Found Error

**Error**: `command not found: pi` or `command not found: opencode`

**Solution:**
```bash
# Reinstall agents inside container
docker exec -it ai-agent-sandbox npm install -g @earendil-works/pi-coding-agent
docker exec -it ai-agent-sandbox npm i -g opencode-ai
```

### LLM Connection Refused

**Error**: `Connection refused` when connecting to LLM server

**Solution:**
1. Ensure LLM server is running locally
2. Check correct port (Ollama: 11434, LM Studio: 1234)
3. Verify `host.docker.internal` resolves correctly from inside container
4. Try using explicit host IP instead of `host.docker.internal`

### Memory/CPU Issues

**Symptoms**: Container exits with OOM or CPU throttling

**Solution:**
```yaml
# Increase limits in docker-compose.yml:
deploy.resources.limits:
  cpus: '4.0'      # More vCPUs
  memory: 8G       # More RAM
```

### Web Terminal Not Accessible

**Symptoms**: Browser times out on `http://<host>:7681`

**Solution:**
1. Enable in `.env`: `ENABLE_WEB_TERMINAL=true`
2. Ensure port isn't blocked by firewall
3. Use container's web terminal: `docker exec -it ai-agent-sandbox bash` (CLI alternative)

---

## 🔄 Maintenance & Updates

### Updating Agent Packages

```bash
# Update both agents to latest versions
docker exec -it ai-agent-sandbox npm update -g @earendil-works/pi-coding-agent opencode-ai

# Or rebuild with pinned version in Dockerfile:
# FROM node:20-bookworm-slim AS base
```

### Cleaning Up Resources

```bash
# Stop and remove container
docker compose down

# Remove image (if needed)
docker rmi ai-agent-sandbox

# Clean up all (container + image + volumes)
docker compose down -v --rmi all
```

---

## 📞 Support & Documentation

- **PI Coding Agent**: https://github.com/earendil-works/pi-coding-agent
- **OpenCode AI**: https://github.com/opencode-ai/coding-agent
- **Docker Compose Docs**: https://docs.docker.com/compose/
- **Security Best Practices**: https://docs.docker.com/engine/security/

---

## 📄 License

This sandbox setup is provided as-is for development and testing purposes.
