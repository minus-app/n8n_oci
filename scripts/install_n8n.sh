#!/bin/bash

# Edit 1
set -euo pipefail

# Credentials injected by Terraform
N8N_BASIC_AUTH_USER="__N8N_USER__"
N8N_BASIC_AUTH_PASSWORD="__N8N_PASSWORD__"
# Ensure all files are created in the user's home directory
cd "$HOME"

# Escape special characters
ESCAPED_USER=$(printf '%s' "$N8N_BASIC_AUTH_USER" | sed -e 's/[\/&|]/\\&/g')
ESCAPED_PASSWORD=$(printf '%s' "$N8N_BASIC_AUTH_PASSWORD" | sed -e 's/[\/&|]/\\&/g')

# Install Docker and Docker Compose
sudo apt update && sudo apt install -y ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io
if [ -n "${USER-}" ]; then
    sudo usermod -aG docker "$USER"
fi
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create Docker Compose file with injected credentials
cat <<EOF | sudo tee docker-compose.yml > /dev/null
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
      - N8N_BASIC_AUTH_USER=$ESCAPED_USER
      - N8N_BASIC_AUTH_PASSWORD=$ESCAPED_PASSWORD
      - N8N_SECURE_COOKIE=false
    volumes:
      - ./n8n_data:/home/node/.n8n
EOF

# Prepare volume and start container
mkdir -p n8n_data
sudo chown -R 1000:1000 n8n_data
sudo docker-compose -p n8n up -d
