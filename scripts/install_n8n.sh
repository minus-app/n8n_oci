#!/bin/bash
set -euo pipefail

# ------------------------------------------------------------------
# Credentials injected by Terraform (placeholders)
# ------------------------------------------------------------------
N8N_BASIC_AUTH_USER="__N8N_USER__"
N8N_BASIC_AUTH_PASSWORD="__N8N_PASSWORD__"

# Ensure all files are created in the user's home directory
cd "$HOME"

# ------------------------------------------------------------------
# Escape credentials for safe YAML single-quoted usage
# YAML rule: inside single quotes, a single quote is written as ''
# ------------------------------------------------------------------
ESCAPED_USER=$(printf '%s' "$N8N_BASIC_AUTH_USER" | sed "s/'/''/g")
ESCAPED_PASSWORD=$(printf '%s' "$N8N_BASIC_AUTH_PASSWORD" | sed "s/'/''/g")

# ------------------------------------------------------------------
# Install Docker Engine + docker compose plugin (Ubuntu)
# ------------------------------------------------------------------
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Docker GPG key
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi

# Docker APT repo
DOCKER_REPO_LINE="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
if ! grep -q "download.docker.com/linux/ubuntu" /etc/apt/sources.list.d/docker.list 2>/dev/null; then
    echo "$DOCKER_REPO_LINE" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
fi

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# ------------------------------------------------------------------
# Add the real user to the docker group (if we know who that is)
# ------------------------------------------------------------------
REAL_USER="${SUDO_USER:-${USER:-}}"
if [ -n "$REAL_USER" ] && id "$REAL_USER" >/dev/null 2>&1; then
    sudo usermod -aG docker "$REAL_USER"
fi

# ------------------------------------------------------------------
# Create docker-compose.yml with injected, safely-quoted credentials
# ------------------------------------------------------------------
cat <<EOF | sudo tee docker-compose.yml > /dev/null
version: "3.8"

services:
  n8n:
    image: n8nio/n8n
    restart: unless-stopped
    container_name: n8n
    ports:
      - "5678:5678"
    environment:
      - GENERIC_TIMEZONE=Europe/Madrid
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER='$ESCAPED_USER'
      - N8N_BASIC_AUTH_PASSWORD='$ESCAPED_PASSWORD'
      - N8N_SECURE_COOKIE=false
    volumes:
      - ./n8n_data:/home/node/.n8n
EOF

# ------------------------------------------------------------------
# Prepare volume and start container
# ------------------------------------------------------------------
mkdir -p n8n_data
# n8n container runs as node:node (1000:1000)
sudo chown -R 1000:1000 n8n_data

# Use docker compose v2 (plugin), not legacy docker-compose
sudo docker compose -p n8n up -d
