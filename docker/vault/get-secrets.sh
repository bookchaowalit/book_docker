#!/bin/bash

# Vault secrets retrieval script for Docker services
# Usage: ./get-secrets.sh <service_name>

export VAULT_ADDR="http://vault.localhost"
export VAULT_TOKEN="myroot"

SERVICE_NAME=$1

if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 <service_name>"
    echo "Available services: postgres, mysql, mariadb, n8n, twenty, open-webui"
    exit 1
fi

case $SERVICE_NAME in
    "postgres")
        echo "# PostgreSQL Secrets from Vault"
        echo "POSTGRES_USER=$(vault kv get -field=username secret/database/postgres)"
        echo "POSTGRES_PASSWORD=$(vault kv get -field=password secret/database/postgres)"
        echo "POSTGRES_HOST=$(vault kv get -field=host secret/database/postgres)"
        echo "POSTGRES_PORT=$(vault kv get -field=port secret/database/postgres)"
        echo "POSTGRES_DB=$(vault kv get -field=database secret/database/postgres)"
        ;;
    "mysql")
        echo "# MySQL Secrets from Vault"
        echo "MYSQL_ROOT_PASSWORD=$(vault kv get -field=root_password secret/database/mysql)"
        echo "MYSQL_USER=$(vault kv get -field=username secret/database/mysql)"
        echo "MYSQL_PASSWORD=$(vault kv get -field=password secret/database/mysql)"
        echo "MYSQL_HOST=$(vault kv get -field=host secret/database/mysql)"
        echo "MYSQL_PORT=$(vault kv get -field=port secret/database/mysql)"
        ;;
    "mariadb")
        echo "# MariaDB Secrets from Vault"
        echo "MARIADB_ROOT_PASSWORD=$(vault kv get -field=root_password secret/database/mariadb)"
        echo "MARIADB_USER=$(vault kv get -field=username secret/database/mariadb)"
        echo "MARIADB_PASSWORD=$(vault kv get -field=password secret/database/mariadb)"
        echo "MARIADB_HOST=$(vault kv get -field=host secret/database/mariadb)"
        echo "MARIADB_PORT=$(vault kv get -field=port secret/database/mariadb)"
        ;;
    "n8n")
        echo "# N8N Secrets from Vault"
        echo "N8N_ENCRYPTION_KEY=$(vault kv get -field=encryption_key secret/app/n8n)"
        echo "N8N_SECURE_COOKIE=$(vault kv get -field=secure_cookie secret/app/n8n)"
        echo "N8N_HOST=$(vault kv get -field=host secret/app/n8n)"
        ;;
    "twenty")
        echo "# Twenty CRM Secrets from Vault"
        echo "APP_SECRET=$(vault kv get -field=app_secret secret/app/twenty)"
        echo "SERVER_URL=$(vault kv get -field=server_url secret/app/twenty)"
        echo "STORAGE_TYPE=$(vault kv get -field=storage_type secret/app/twenty)"
        # Add database connection from vault
        echo "PG_DATABASE_USER=$(vault kv get -field=username secret/database/postgres)"
        echo "PG_DATABASE_PASSWORD=$(vault kv get -field=password secret/database/postgres)"
        echo "PG_DATABASE_HOST=$(vault kv get -field=host secret/database/postgres)"
        ;;
    "open-webui")
        echo "# Open WebUI Secrets from Vault"
        echo "OPENAI_API_KEY=$(vault kv get -field=openai_api_key secret/app/open-webui)"
        ;;
    *)
        echo "Unknown service: $SERVICE_NAME"
        echo "Available services: postgres, mysql, mariadb, n8n, twenty, open-webui"
        exit 1
        ;;
esac
