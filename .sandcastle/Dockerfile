FROM node:22-bookworm

# Install system dependencies + ripgrep (for code audits)
RUN apt-get update && apt-get install -y \
  git \
  curl \
  jq \
  ripgrep \
  python3 \
  python3-pip \
  && rm -rf /var/lib/apt/lists/*

# Install PowerShell 7 via Microsoft package repository
RUN curl -fsSL https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -o /tmp/packages-microsoft-prod.deb \
  && dpkg -i /tmp/packages-microsoft-prod.deb \
  && rm /tmp/packages-microsoft-prod.deb \
  && apt-get update && apt-get install -y powershell \
  && rm -rf /var/lib/apt/lists/*

# Install PowerShell modules for build and test
# Pester 5.x — test framework
# ModuleBuilder — assembles split source into single .psm1
# Configuration — ModuleBuilder dependency
# PSScriptAnalyzer — static analysis (optional lint pass)
RUN pwsh -NoProfile -Command "\
  Install-Module -Name Pester -RequiredVersion 5.6.0 -Force -SkipPublisherCheck -Scope AllUsers; \
  Install-Module -Name ModuleBuilder -Force -Scope AllUsers; \
  Install-Module -Name Configuration -Force -Scope AllUsers; \
  Install-Module -Name PSScriptAnalyzer -Force -Scope AllUsers"

# Python deps for PS5.1 smoke testing (WinRM)
RUN pip3 install --break-system-packages pywinrm

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && apt-get update && apt-get install -y gh \
  && rm -rf /var/lib/apt/lists/*

# Build-args for UID/GID alignment: sandcastle docker build-image
# defaults these to the host user's UID/GID so image-built files
# and bind-mounted files share an owner without runtime chown.
ARG AGENT_UID=1000
ARG AGENT_GID=1000

# Rename the base image's "node" user to "agent" and align UID/GID.
RUN groupmod -o -g $AGENT_GID node && usermod -o -u $AGENT_UID -g $AGENT_GID -d /home/agent -m -l agent node

# Install pi coding agent (run as root before USER agent)
RUN npm install -g @mariozechner/pi-coding-agent

# Create pwsh profile with Build-ModuleLocal helper
RUN mkdir -p /home/agent/.config/powershell \
  && printf 'function Build-ModuleLocal {\n  Build-Module -SourcePath ./Source/PSSymantecSEPM.psd1 -SemVer 0.0.1\n}\n' > /home/agent/.config/powershell/Microsoft.PowerShell_profile.ps1 \
  && chown -R ${AGENT_UID}:${AGENT_GID} /home/agent/.config

USER ${AGENT_UID}:${AGENT_GID}

WORKDIR /home/agent

# In worktree sandbox mode, Sandcastle bind-mounts the git worktree at /home/agent/workspace
# and overrides the working directory to /home/agent/workspace at container start.
# Structure your Dockerfile so that /home/agent/workspace can serve as the project root.
ENTRYPOINT ["sleep", "infinity"]
