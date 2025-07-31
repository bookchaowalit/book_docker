#!/bin/bash

# Update all .env files to use Vault secrets
# This script creates new .env files that source secrets from Vault

export VAULT_ADDR="http://vault.localhost"
export VAULT_TOKEN="myroot"

SCRIPT_DIR="/home/bookchaowalit/book/book_docker/vault"

echo "🔄 Updating .env files to use Vault secrets..."

# Update Twenty .env
echo "📝 Updating Twenty .env file..."
cat > /home/bookchaowalit/book/book_docker/twenty/.env << 'EOF'
# Twenty CRM Environment Variables - Sourced from HashiCorp Vault
# Generated automatically - DO NOT EDIT MANUALLY

# Load from Vault using helper script
SERVER_URL=$(cd /home/bookchaowalit/book/book_docker/vault && ./get-secrets.sh twenty | grep SERVER_URL | cut -d'=' -f2)
STORAGE_TYPE=$(cd /home/bookchaowalit/book/book_docker/vault && ./get-secrets.sh twenty | grep STORAGE_TYPE | cut -d'=' -f2)
STORAGE_S3_REGION=
STORAGE_S3_NAME=
STORAGE_S3_ENDPOINT=

# Database Configuration from Vault
PG_DATABASE_USER=$(cd /home/bookchaowalit/book/book_docker/vault && ./get-secrets.sh twenty | grep PG_DATABASE_USER | cut -d'=' -f2)
PG_DATABASE_PASSWORD=$(cd /home/bookchaowalit/book/book_docker/vault && ./get-secrets.sh twenty | grep PG_DATABASE_PASSWORD | cut -d'=' -f2)
PG_DATABASE_HOST=$(cd /home/bookchaowalit/book/book_docker/vault && ./get-secrets.sh twenty | grep PG_DATABASE_HOST | cut -d'=' -f2)
PG_DATABASE_PORT=5432
PG_DATABASE_NAME=twenty

# Redis Configuration
REDIS_URL=redis://redis:6379

# Application Secret from Vault
APP_SECRET=$(cd /home/bookchaowalit/book/book_docker/vault && ./get-secrets.sh twenty | grep APP_SECRET | cut -d'=' -f2)

# Tag
TAG=latest
EOF

# Update N8N .env
echo "📝 Updating N8N .env file..."
cat > /home/bookchaowalit/book/book_docker/n8n/.env << 'EOF'
# N8N Environment Variables - Sourced from HashiCorp Vault
# Generated automatically - DO NOT EDIT MANUALLY

# Basic Configuration
N8N_PORT=5678
N8N_HOST=n8n.localhost
N8N_PROTOCOL=http
N8N_SECURE_COOKIE=$(cd /home/bookchaowalit/book/book_docker/vault && ./get-secrets.sh n8n | grep N8N_SECURE_COOKIE | cut -d'=' -f2)

# Database Configuration from Vault
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=$(cd /home/bookchaowalit/book/book_docker/vault && ./get-secrets.sh postgres | grep POSTGRES_HOST | cut -d'=' -f2)
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=$(cd /home/bookchaowalit/book/book_docker/vault && ./get-secrets.sh postgres | grep POSTGRES_USER | cut -d'=' -f2)
DB_POSTGRESDB_PASSWORD=$(cd /home/bookchaowalit/book/book_docker/vault && ./get-secrets.sh postgres | grep POSTGRES_PASSWORD | cut -d'=' -f2)

# Generic timezone and encryption key from Vault
GENERIC_TIMEZONE=Europe/Berlin
N8N_ENCRYPTION_KEY=$(cd /home/bookchaowalit/book/book_docker/vault && ./get-secrets.sh n8n | grep N8N_ENCRYPTION_KEY | cut -d'=' -f2)

# Webhook URL
WEBHOOK_URL=http://n8n.localhost/

# User Management
N8N_USER_MANAGEMENT_DISABLED=true
EOF

# Update Open WebUI .env
echo "📝 Updating Open WebUI .env file..."
cat > /home/bookchaowalit/book/book_docker/open-web-ui/.env << 'EOF'
# Open WebUI Environment Variables - Sourced from HashiCorp Vault
# Generated automatically - DO NOT EDIT MANUALLY

OPENAI_API_KEY=$(cd /home/bookchaowalit/book/book_docker/vault && ./get-secrets.sh open-webui | grep OPENAI_API_KEY | cut -d'=' -f2)
EOF

# Update PostgreSQL .env
echo "📝 Updating PostgreSQL .env file..."
cat > /home/bookchaowalit/book/book_docker/postgres/.env << 'EOF'
# PostgreSQL Environment Variables - Sourced from HashiCorp Vault
# Generated automatically - DO NOT EDIT MANUALLY

POSTGRES_DB=$(cd /home/bookchaowalit/book/book_docker/vault && ./get-secrets.sh postgres | grep POSTGRES_DB | cut -d'=' -f2)
POSTGRES_USER=$(cd /home/bookchaowalit/book/book_docker/vault && ./get-secrets.sh postgres | grep POSTGRES_USER | cut -d'=' -f2)
POSTGRES_PASSWORD=$(cd /home/bookchaowalit/book/book_docker/vault && ./get-secrets.sh postgres | grep POSTGRES_PASSWORD | cut -d'=' -f2)
PGDATA=/var/lib/postgresql/data
EOF

echo "✅ All .env files updated to use Vault secrets!"
echo "🔄 To apply changes, restart your Docker services"
echo "💡 Use: ./docker-compose-manager.sh down <service> && ./docker-compose-manager.sh up <service>"
