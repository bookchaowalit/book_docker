#!/bin/bash

# HashiCorp Vault Initialization Script
# This script initializes Vault with development/testing secrets
# WARNING: This is for development only - use proper secret management in production

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔐 Initializing HashiCorp Vault with development secrets...${NC}"
echo -e "${YELLOW}⚠️  WARNING: This is for development only!${NC}"

# Wait for Vault to be ready
echo "⏳ Waiting for Vault to be ready..."
sleep 10

# Set Vault address
export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="myroot"

# Enable the KV secrets engine (if not already enabled)
echo "🔧 Enabling KV secrets engine..."
vault secrets enable -path=secret kv-v2 2>/dev/null || echo "KV engine already enabled"

# Add Database Secrets
echo "🗄️  Adding database secrets..."
vault kv put secret/db/postgres \
    username=postgres \
    password=your_postgres_password_here \
    database=postgres \
    host=postgres \
    port=5432

vault kv put secret/db/mysql \
    root_password=your_mysql_root_password_here \
    database=app_db \
    username=app_user \
    password=your_mysql_password_here \
    host=mysql \
    port=3306

vault kv put secret/db/mariadb \
    root_password=your_mariadb_root_password_here \
    database=app_db \
    username=app_user \
    password=your_mariadb_password_here \
    host=mariadb \
    port=3306

# Add Application Secrets
echo "📱 Adding application secrets..."
vault kv put secret/app/n8n \
    webhook_url=http://n8n.localhost \
    encryption_key=your_n8n_encryption_key_here

vault kv put secret/app/twenty \
    app_secret=your_twenty_secret_key_here \
    server_url=http://twenty.localhost \
    storage_type=local

vault kv put secret/app/open-webui \
    openai_api_key=YOUR_OPENAI_API_KEY_HERE

# Kubernetes Secrets (Monitoring)
echo "☸️  Adding Kubernetes secrets..."
vault kv put secret/k8s/grafana \
    admin_user=admin \
    admin_password=your_grafana_password_here

vault kv put secret/k8s/prometheus \
    retention_time=15d \
    storage_path=/prometheus

# Storage Secrets
echo "💾 Adding storage secrets..."
vault kv put secret/storage/minio \
    access_key=your_minio_access_key_here \
    secret_key=your_minio_secret_key_here

# Infrastructure Secrets
echo "🏗️  Adding infrastructure secrets..."
vault kv put secret/infra/traefik \
    api_dashboard_user=admin \
    api_dashboard_password=your_traefik_password_here

# Backup Configuration
echo "💾 Adding backup configuration..."
vault kv put secret/backup/config \
    backup_path=/backups \
    retention_days=30 \
    compression=gzip

echo -e "${GREEN}✅ Vault initialization completed!${NC}"
echo ""
echo -e "${YELLOW}📝 Next steps:${NC}"
echo "1. Update the placeholder values with your actual secrets"
echo "2. Use 'vault kv get secret/path/to/secret' to retrieve secrets"
echo "3. Update your applications to use Vault for secret management"
echo ""
echo -e "${GREEN}🔍 Example commands:${NC}"
echo "vault kv get secret/db/postgres"
echo "vault kv put secret/db/postgres password=new_password"
