#!/bin/bash

# Vault Management Script
# Central management for all HashiCorp Vault operations

export VAULT_ADDR="http://vault.localhost"
export VAULT_TOKEN="myroot"

SCRIPT_DIR="/home/bookchaowalit/book/book_docker/vault"

show_help() {
    echo "🔐 HashiCorp Vault Management Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  init                Initialize Vault with all secrets"
    echo "  status              Show Vault status and list secrets"
    echo "  get <service>       Get secrets for a specific service"
    echo "  update-env          Update all .env files with Vault secrets"
    echo "  sync-k8s            Sync secrets to Kubernetes"
    echo "  backup              Backup Vault secrets only (JSON file)"
    echo "  backup-volumes      Backup Docker volumes only"
    echo "  backup-complete     Complete backup (Vault + Volumes + Configs)"
    echo "  restore <file>      Restore secrets from JSON backup"
    echo "  add-secret          Add a new secret interactively"
    echo "  rotate <path>       Rotate a specific secret"
    echo ""
    echo "Examples:"
    echo "  $0 init                    # Initialize Vault"
    echo "  $0 get twenty             # Get Twenty CRM secrets"
    echo "  $0 update-env             # Update all .env files"
    echo "  $0 sync-k8s               # Sync to Kubernetes"
    echo "  $0 backup                 # Backup Vault secrets only"
    echo "  $0 backup-complete        # Complete infrastructure backup"
}

check_vault() {
    if ! curl -s $VAULT_ADDR/v1/sys/health > /dev/null; then
        echo "❌ Vault is not accessible at $VAULT_ADDR"
        echo "💡 Make sure Vault is running: cd /home/bookchaowalit/book/book_docker/vault && docker-compose up -d"
        exit 1
    fi
}

case "${1:-help}" in
    "init")
        echo "🔄 Initializing Vault..."
        $SCRIPT_DIR/init-vault.sh
        ;;
    "status")
        check_vault
        echo "🔐 Vault Status:"
        vault status
        echo ""
        echo "📝 Available secrets:"
        vault kv list secret/ 2>/dev/null || echo "No secrets found"
        ;;
    "get")
        if [ -z "$2" ]; then
            echo "❌ Please specify a service name"
            echo "Available services: postgres, mysql, mariadb, n8n, twenty, open-webui"
            exit 1
        fi
        check_vault
        $SCRIPT_DIR/get-secrets.sh "$2"
        ;;
    "update-env")
        check_vault
        echo "🔄 Updating .env files with Vault secrets..."
        $SCRIPT_DIR/update-env-files.sh
        ;;
    "sync-k8s")
        check_vault
        echo "☸️  Syncing secrets to Kubernetes..."
        $SCRIPT_DIR/sync-k8s-secrets.sh
        ;;
    "backup")
        check_vault
        BACKUP_FILE="vault-secrets-$(date +%Y%m%d-%H%M%S).json"
        echo "💾 Creating Vault secrets backup: $BACKUP_FILE"

        # Create backup directory
        mkdir -p $SCRIPT_DIR/backups/vault

        # Export secrets
        {
            echo "{"
            echo '  "database": {'
            echo '    "postgres": ' $(vault kv get -format=json secret/database/postgres | jq .data.data)','
            echo '    "mysql": ' $(vault kv get -format=json secret/database/mysql | jq .data.data)','
            echo '    "mariadb": ' $(vault kv get -format=json secret/database/mariadb | jq .data.data)
            echo '  },'
            echo '  "app": {'
            echo '    "n8n": ' $(vault kv get -format=json secret/app/n8n | jq .data.data)','
            echo '    "twenty": ' $(vault kv get -format=json secret/app/twenty | jq .data.data)','
            echo '    "open-webui": ' $(vault kv get -format=json secret/app/open-webui | jq .data.data)
            echo '  },'
            echo '  "k8s": {'
            echo '    "grafana": ' $(vault kv get -format=json secret/k8s/grafana | jq .data.data)
            echo '  }'
            echo "}"
        } > $SCRIPT_DIR/backups/vault/$BACKUP_FILE

        echo "✅ Vault secrets backup created: $SCRIPT_DIR/backups/vault/$BACKUP_FILE"
        ;;
    "backup-volumes")
        echo "🗄️  Running Docker volumes backup..."
        chmod +x $SCRIPT_DIR/backup-volumes.sh
        $SCRIPT_DIR/backup-volumes.sh
        ;;
    "backup-complete")
        echo "🚀 Running complete infrastructure backup..."
        chmod +x $SCRIPT_DIR/complete-backup.sh
        $SCRIPT_DIR/complete-backup.sh
        ;;
    "backup")
        ;;
    "add-secret")
        check_vault
        echo "➕ Adding new secret interactively"
        echo "Secret path (e.g., secret/app/myapp):"
        read -r SECRET_PATH
        echo "Key=Value pairs (press Enter twice to finish):"

        PAIRS=""
        while true; do
            read -r line
            if [ -z "$line" ]; then
                break
            fi
            PAIRS="$PAIRS $line"
        done

        vault kv put $SECRET_PATH $PAIRS
        echo "✅ Secret added successfully"
        ;;
    "rotate")
        if [ -z "$2" ]; then
            echo "❌ Please specify a secret path"
            exit 1
        fi
        check_vault
        echo "🔄 Rotating secret: $2"
        echo "💡 This would generate new values for the secret"
        echo "🚧 Feature coming soon - manual rotation required for now"
        ;;
    "help"|*)
        show_help
        ;;
esac
