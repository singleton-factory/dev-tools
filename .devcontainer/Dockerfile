FROM mcr.microsoft.com/devcontainers/base:debian

USER root

# Set sources.list to Hetzner mirror
RUN curl -fsSL \
    https://raw.githubusercontent.com/singleton-factory/dev-tools/main/Linux/setHetznerMirror.sh \
    | bash

# Install required packages
RUN apt-get update \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/home/vscode/.opencode/bin:/home/vscode/.local/bin:${PATH}"

# Install OpenCode, load config + AGENTS.md from the GitHub repository
RUN curl -fsSL \
    https://raw.githubusercontent.com/singleton-factory/dev-tools/main/Linux/opencode/setup.sh \
    | bash
