###############################################################################
# OpenClaw Gateway – Docker Image
#
# IMPORTANT: Runtime installs are lost on container restart. All binaries
# needed by skills MUST be installed here at build time. If you add a skill
# that needs a new binary, update this Dockerfile and rebuild.
###############################################################################

FROM node:22-bookworm-slim

# Install system dependencies as root
RUN apt-get update && apt-get install -y --no-install-recommends \
  git \
  curl \
  chromium \
  ca-certificates \
  gnupg \
  tini \
  python3 \
  python3-venv \
  && rm -rf /var/lib/apt/lists/*

# Install uv (fast Python package manager — required by nano-pdf and other Python skills)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
  && mv /root/.local/bin/uv /usr/local/bin/uv \
  && mv /root/.local/bin/uvx /usr/local/bin/uvx

# Install gogcli (Google Workspace CLI — required by gog skill)
ARG GOGCLI_VERSION=0.15.0
RUN ARCH=$(dpkg --print-architecture) \
  && curl -fsSL "https://github.com/openclaw/gogcli/releases/download/v${GOGCLI_VERSION}/gogcli_${GOGCLI_VERSION}_linux_${ARCH}.tar.gz" \
     -o /tmp/gogcli.tar.gz \
  && tar -xzf /tmp/gogcli.tar.gz -C /usr/local/bin gog \
  && chmod +x /usr/local/bin/gog \
  && mv /usr/local/bin/gog /usr/local/bin/gog-bin \
  && echo '#!/bin/sh\nexport GOG_KEYRING_BACKEND=file\nexport GOG_KEYRING_PASSWORD=${GOG_KEYRING_PASSWORD:-openclaw-gog-keyring}\nexport XDG_DATA_HOME=/home/node/.openclaw/.local/share\nexec /usr/local/bin/gog-bin "$@"' > /usr/local/bin/gog \
  && chmod +x /usr/local/bin/gog \
  && rm /tmp/gogcli.tar.gz

# Install GitHub CLI (required by github skill)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update && apt-get install -y --no-install-recommends gh \
  && mv /usr/bin/gh /usr/bin/gh-bin \
  && echo '#!/bin/sh\nexport GH_CONFIG_DIR=/home/node/.openclaw/gh\nexec /usr/bin/gh-bin "$@"' > /usr/bin/gh \
  && chmod +x /usr/bin/gh \
  && rm -rf /var/lib/apt/lists/*

# Pin OpenClaw version for reproducible builds — bump explicitly when upgrading
ARG OPENCLAW_VERSION=2026.6.1
RUN npm install -g openclaw@${OPENCLAW_VERSION}

# Install ClawHub CLI for skill management
RUN npm install -g clawhub

# Create OpenClaw directories owned by node
RUN mkdir -p /home/node/.openclaw/workspace /.clawhub \
  && chown -R node:node /home/node/.openclaw /.clawhub

# Copy skills manifest, workspace templates, and entrypoint
COPY config/skills-manifest.txt /opt/config/skills-manifest.txt
RUN sed -i 's/\r$//' /opt/config/skills-manifest.txt && echo "" >> /opt/config/skills-manifest.txt
COPY workspace-templates/ /opt/workspace-templates/
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh

USER node

ENTRYPOINT ["tini", "--", "entrypoint.sh"]
