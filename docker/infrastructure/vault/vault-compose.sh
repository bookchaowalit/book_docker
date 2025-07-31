#!/bin/bash

# Vault-enabled Docker Compose launcher
# This script removes the need for .env files by fetching secrets directly from Vault

SERVICE_NAME="$1"
VAULT_SCRIPT_DIR="/home/bookchaowalit/book/book_docker/vault"

if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 <service_name>"
    echo "Available services: twenty, n8n, postgres, mysql, mariadb, open-webui"
    exit 1
fi

echo "🔐 Loading secrets from Vault for: $SERVICE_NAME"

# Source the vault environment
source "$VAULT_SCRIPT_DIR/vault-env.sh" "$SERVICE_NAME"

if [ $? -ne 0 ]; then
    echo "❌ Failed to load secrets from Vault"
    exit 1
fi

# Now run docker-compose with the environment variables
cd "/home/bookchaowalit/book/book_docker/$SERVICE_NAME"

if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found in /home/bookchaowalit/book/book_docker/$SERVICE_NAME"
    exit 1
fi

echo "🚀 Starting $SERVICE_NAME with Vault secrets..."
docker-compose up -d

echo "✅ $SERVICE_NAME started with Vault-managed secrets!"
