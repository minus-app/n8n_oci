#!/bin/bash
set -euo pipefail

# ------------------------------------------------------------------
# Credentials injected by Terraform
# ------------------------------------------------------------------
N8N_BASIC_AUTH_USER="__N8N_USER__"
N8N_BASIC_AUTH_PASSWORD="__N8N_PASSWORD__"

cd "$HOME"

# Escape credentials for YAML-safe single quotes
ESCAPED_USER=$(printf '%s' "$N8N_BASIC_AUTH_USER" | sed "s/'/''/g")
ESCAPED_PASSWORD=$(printf '%s' "$N8N_BASIC_AUTH_PASSWORD" | sed "s/'/''/g")

# ------------------------------------------------------------------
# Install Docker Engine + docker compose plugin
# ------------------------------------------------------------------
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release

if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
 https://download.docker.com/linux/ubuntu \
 $(lsb_release -cs) stable" \
 | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add actual real user to docker group
REAL_USER="${SUDO_USER:-${USER:-}}"
if [ -n "$REAL_USER" ] && id "$REAL_USER" >/dev/null 2>&1; then
    sudo usermod -aG docker "$REAL_USER"
fi

# ------------------------------------------------------------------
# Create docker-compose.yml with correct Pacific timezone
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
      - GENERIC_TIMEZONE=America/Los_Angeles
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER='$ESCAPED_USER'
      - N8N_BASIC_AUTH_PASSWORD='$ESCAPED_PASSWORD'
      - N8N_SECURE_COOKIE=false
    volumes:
      - ./n8n_data:/home/node/.n8n
EOF

# ------------------------------------------------------------------
# Prepare n8n data volume
# ------------------------------------------------------------------
mkdir -p n8n_data
sudo chown -R 1000:1000 n8n_data

# ------------------------------------------------------------------
# Start n8n
# ------------------------------------------------------------------
sudo docker compose -p n8n up -d
