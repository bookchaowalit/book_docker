#!/bin/bash

# Vault Environment Injector
# This script fetches secrets from Vault and exports them as environment variables
# Usage: source ./vault-env.sh <service_name>

export VAULT_ADDR="http://vault.localhost"
export VAULT_TOKEN="myroot"

SERVICE_NAME=$1

if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: source $0 <service_name>"
    echo "Available services: postgres, mysql, mariadb, n8n, twenty, open-webui"
    return 1
fi

# Function to safely get secret from Vault
get_vault_secret() {
    local path=$1
    local field=$2
    vault kv get -field="$field" "$path" 2>/dev/null || echo ""
}

case $SERVICE_NAME in
    "postgres")
        export POSTGRES_USER=$(get_vault_secret "secret/database/postgres" "username")
        export POSTGRES_PASSWORD=$(get_vault_secret "secret/database/postgres" "password")
        export POSTGRES_DB=$(get_vault_secret "secret/database/postgres" "database")
        export PGDATA="/var/lib/postgresql/data"
        ;;
    "mysql")
        export MYSQL_ROOT_PASSWORD=$(get_vault_secret "secret/database/mysql" "root_password")
        export MYSQL_USER=$(get_vault_secret "secret/database/mysql" "username")
        export MYSQL_PASSWORD=$(get_vault_secret "secret/database/mysql" "password")
        ;;
    "mariadb")
        export MARIADB_ROOT_PASSWORD=$(get_vault_secret "secret/database/mariadb" "root_password")
        export MARIADB_USER=$(get_vault_secret "secret/database/mariadb" "username")
        export MARIADB_PASSWORD=$(get_vault_secret "secret/database/mariadb" "password")
        ;;
    "n8n")
        export N8N_PORT=5678
        export N8N_HOST="n8n.localhost"
        export N8N_PROTOCOL="http"
        export N8N_SECURE_COOKIE=$(get_vault_secret "secret/app/n8n" "secure_cookie")
        export N8N_ENCRYPTION_KEY=$(get_vault_secret "secret/app/n8n" "encryption_key")
        export GENERIC_TIMEZONE="Europe/Berlin"
        export WEBHOOK_URL="http://n8n.localhost/"
        export N8N_USER_MANAGEMENT_DISABLED="true"
        # Database from Vault
        export DB_TYPE="postgresdb"
        export DB_POSTGRESDB_HOST=$(get_vault_secret "secret/database/postgres" "host")
        export DB_POSTGRESDB_PORT="5432"
        export DB_POSTGRESDB_DATABASE="n8n"
        export DB_POSTGRESDB_USER=$(get_vault_secret "secret/database/postgres" "username")
        export DB_POSTGRESDB_PASSWORD=$(get_vault_secret "secret/database/postgres" "password")
        ;;
    "twenty")
        export NODE_PORT=3000
        export SERVER_URL=$(get_vault_secret "secret/app/twenty" "server_url")
        export STORAGE_TYPE=$(get_vault_secret "secret/app/twenty" "storage_type")
        export APP_SECRET=$(get_vault_secret "secret/app/twenty" "app_secret")
        export REDIS_URL="redis://redis:6379"
        export TAG="latest"
        # Database from Vault
        export PG_DATABASE_USER=$(get_vault_secret "secret/database/postgres" "username")
        export PG_DATABASE_PASSWORD=$(get_vault_secret "secret/database/postgres" "password")
        export PG_DATABASE_HOST=$(get_vault_secret "secret/database/postgres" "host")
        export PG_DATABASE_PORT="5432"
        export PG_DATABASE_NAME="twenty"
        # Build database URL
        export PG_DATABASE_URL="postgres://$PG_DATABASE_USER:$PG_DATABASE_PASSWORD@$PG_DATABASE_HOST:$PG_DATABASE_PORT/$PG_DATABASE_NAME"
        ;;
    "open-webui")
        export OPENAI_API_KEY=$(get_vault_secret "secret/app/open-webui" "openai_api_key")
        ;;
    *)
        echo "Unknown service: $SERVICE_NAME"
        return 1
        ;;
esac

echo "✅ Environment variables loaded from Vault for: $SERVICE_NAME"
