# ============================================
# Docker AI Agent Sandbox - Production Build
# Base: Node.js LTS 20 (bookworm-slim)
# ============================================

FROM node:20-bookworm-slim

LABEL description="AI Agent Sandbox for PI and OpenCode coding agents"

# Install runtime dependencies: curl for LLM connectivity validation
# (gnupg not needed — no external repos or signature verification)
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    git \
    vim \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Github CLI tool download
RUN mkdir -p -m 755 /etc/apt/keyrings \
	&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& mkdir -p -m 755 /etc/apt/sources.list.d \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& apt update \
	&& apt install gh -y

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Create non-root runtime user and group (UID 2000, since 1000 is taken by 'node' in base image)
RUN groupadd -g 2000 agentgroup && \
    useradd -u 2000 -g 2000 -m -s /bin/bash agentuser

# Set up working directory for the runtime
WORKDIR /app

# Create config directories BEFORE copying (COPY needs parent dirs to exist)
RUN mkdir -p /home/agentuser/.config/opencode \
    && mkdir -p /home/agentuser/.pi/agent \
    && chown -R agentuser:agentgroup /home/agentuser

# Copy config templates baked into image at build time (as root, then set ownership)
COPY --chown=agentuser:agentgroup opencode-config.json /home/agentuser/.config/opencode/opencode.json
COPY --chown=agentuser:agentgroup pi-models.json /home/agentuser/.pi/agent/models.json

# Create app directories and set ownership
RUN mkdir -p /app/workspace \
    && chown agentuser:agentgroup /app/workspace \
    && chmod 750 /app/workspace

# Copy entrypoint script (as root, before USER switch)
COPY --chown=root:root entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Install global npm packages as root (before switching to non-root user)
# This avoids permission issues with /usr/local/lib/node_modules
ENV NPM_CONFIG_LOGLEVEL=warn
# Pin versions for reproducible builds — update these before each production build
RUN npm install -g @earendil-works/pi-coding-agent@0.74.0 \
    && npm i -g opencode-ai@1.14.48

# Clean up npm cache and build dependencies (as root)
# Keep curl — it's needed at runtime for LLM connectivity validation
RUN npm cache clean --force \
    # && apt-get purge -y ca-certificates \
    # && apt-get autoremove -y \
    && rm -rf /root/.npm /root/.cache /tmp/*

# Switch to non-root user for all subsequent operations and runtime
USER agentuser

# Set default command to entrypoint script
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["bash"]
