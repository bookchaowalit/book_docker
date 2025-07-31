#!/bin/bash

# Complete Infrastructure Backup Script
# Backs up both HashiCorp Vault secrets and Docker volumes
# Designed for Apache Airflow scheduling

export VAULT_ADDR="http://vault.localhost"
export VAULT_TOKEN="myroot"

SCRIPT_DIR="/home/bookchaowalit/book/book_docker/vault"
BACKUP_BASE_DIR="/home/bookchaowalit/book/book_docker/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_BASE_DIR/complete/$TIMESTAMP"

# Create backup directory structure
mkdir -p "$BACKUP_DIR"/{vault,volumes,configs,logs}

echo "🚀 Starting Complete Infrastructure Backup - $TIMESTAMP"
echo "📁 Main backup directory: $BACKUP_DIR"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$BACKUP_DIR/logs/backup.log"
}

# Function to check if Vault is accessible
check_vault() {
    if ! curl -s $VAULT_ADDR/v1/sys/health > /dev/null; then
        log "❌ Vault is not accessible at $VAULT_ADDR"
        return 1
    fi
    return 0
}

# 1. Backup Vault Secrets
log "🔐 Starting Vault secrets backup..."
if check_vault; then
    # Export all secrets to JSON
    {
        echo "{"
        echo '  "metadata": {'
        echo '    "backup_date": "'$(date -Iseconds)'",'
        echo '    "vault_addr": "'$VAULT_ADDR'",'
        echo '    "vault_version": "'$(vault version | head -1)'"'
        echo '  },'
        echo '  "secrets": {'
        echo '    "database": {'
        echo '      "postgres": ' $(vault kv get -format=json secret/database/postgres 2>/dev/null | jq .data.data || echo 'null')','
        echo '      "mysql": ' $(vault kv get -format=json secret/database/mysql 2>/dev/null | jq .data.data || echo 'null')','
        echo '      "mariadb": ' $(vault kv get -format=json secret/database/mariadb 2>/dev/null | jq .data.data || echo 'null')
        echo '    },'
        echo '    "applications": {'
        echo '      "n8n": ' $(vault kv get -format=json secret/app/n8n 2>/dev/null | jq .data.data || echo 'null')','
        echo '      "twenty": ' $(vault kv get -format=json secret/app/twenty 2>/dev/null | jq .data.data || echo 'null')','
        echo '      "open-webui": ' $(vault kv get -format=json secret/app/open-webui 2>/dev/null | jq .data.data || echo 'null')
        echo '    },'
        echo '    "kubernetes": {'
        echo '      "grafana": ' $(vault kv get -format=json secret/k8s/grafana 2>/dev/null | jq .data.data || echo 'null')
        echo '    }'
        echo '  }'
        echo "}"
    } > "$BACKUP_DIR/vault/secrets.json"

    # Backup Vault policies
    vault policy list > "$BACKUP_DIR/vault/policies_list.txt" 2>/dev/null
    for policy in $(vault policy list 2>/dev/null); do
        vault policy read "$policy" > "$BACKUP_DIR/vault/policy_${policy}.hcl" 2>/dev/null
    done

    log "✅ Vault secrets backup completed"
else
    log "⚠️  Skipping Vault backup - Vault not accessible"
fi

# 2. Backup Docker Volumes
log "🗄️  Starting Docker volumes backup..."
VOLUMES=$(docker volume ls --format "{{.Name}}" | grep -E "^[a-zA-Z]")

for volume in $VOLUMES; do
    log "📦 Backing up volume: $volume"

    docker run --rm \
        -v "$volume":/data:ro \
        -v "$BACKUP_DIR/volumes":/backup \
        alpine:latest \
        tar czf "/backup/${volume}.tar.gz" -C /data . 2>/dev/null

    if [ $? -eq 0 ]; then
        local size=$(du -h "$BACKUP_DIR/volumes/${volume}.tar.gz" 2>/dev/null | cut -f1)
        log "✅ Volume $volume backed up ($size)"
    else
        log "❌ Failed to backup volume $volume"
    fi
done

# Create volumes metadata
docker volume ls --format "table {{.Driver}}\t{{.Name}}\t{{.Scope}}" > "$BACKUP_DIR/volumes/volumes_list.txt"

# 3. Backup Configuration Files
log "📄 Backing up configuration files..."
cp -r /home/bookchaowalit/book/book_docker/vault/config "$BACKUP_DIR/configs/" 2>/dev/null || true
cp /home/bookchaowalit/book/book_docker/vault/.env "$BACKUP_DIR/configs/vault.env" 2>/dev/null || true

# Copy important docker-compose files
find /home/bookchaowalit/book/book_docker -name "docker-compose.yml" -exec cp {} "$BACKUP_DIR/configs/" \; 2>/dev/null || true
find /home/bookchaowalit/book/book_docker -name ".env" -exec cp {} "$BACKUP_DIR/configs/" \; 2>/dev/null || true

# 4. Create comprehensive manifest
log "📋 Creating backup manifest..."
cat > "$BACKUP_DIR/backup_manifest.json" << EOF
{
  "backup_info": {
    "type": "complete_infrastructure",
    "timestamp": "$TIMESTAMP",
    "date": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "user": "$(whoami)"
  },
  "components": {
    "vault": {
      "secrets_backed_up": $([ -f "$BACKUP_DIR/vault/secrets.json" ] && echo "true" || echo "false"),
      "policies_count": $([ -f "$BACKUP_DIR/vault/policies_list.txt" ] && wc -l < "$BACKUP_DIR/vault/policies_list.txt" || echo "0")
    },
    "docker_volumes": {
      "volumes_count": $(echo "$VOLUMES" | wc -l),
      "volumes": [
$(echo "$VOLUMES" | sed 's/^/        "/' | sed 's/$/",/' | sed '$ s/,$//')
      ]
    },
    "configurations": {
      "files_backed_up": $(find "$BACKUP_DIR/configs" -type f 2>/dev/null | wc -l)
    }
  },
  "backup_size": {
    "total": "$(du -sh "$BACKUP_DIR" | cut -f1)",
    "vault": "$(du -sh "$BACKUP_DIR/vault" 2>/dev/null | cut -f1 || echo '0B')",
    "volumes": "$(du -sh "$BACKUP_DIR/volumes" 2>/dev/null | cut -f1 || echo '0B')",
    "configs": "$(du -sh "$BACKUP_DIR/configs" 2>/dev/null | cut -f1 || echo '0B')"
  }
}
EOF

# 5. Create restoration instructions
cat > "$BACKUP_DIR/RESTORE_INSTRUCTIONS.md" << 'EOF'
# Infrastructure Restore Instructions

## Prerequisites
- Docker and docker-compose installed
- kubectl configured (for Kubernetes secrets)
- HashiCorp Vault binary installed

## Restore Process

### 1. Restore Docker Volumes
```bash
# For each volume backup
docker volume create <volume_name>
docker run --rm -v <volume_name>:/data -v $(pwd)/volumes:/backup alpine:latest tar xzf /backup/<volume_name>.tar.gz -C /data
```

### 2. Restore Vault Secrets
```bash
# Start Vault first
cd /home/bookchaowalit/book/book_docker/vault
docker-compose up -d

# Import secrets (manual process - review secrets.json)
vault kv put secret/database/postgres username=... password=...
# etc.
```

### 3. Restore Configuration Files
```bash
# Copy configuration files back to their locations
cp configs/* /home/bookchaowalit/book/book_docker/
```

### 4. Restart Services
```bash
cd /home/bookchaowalit/book/book_docker
./docker-compose-manager.sh up <service_name>
```
EOF

# 6. Compress the entire backup
log "🗜️  Compressing backup archive..."
cd "$BACKUP_BASE_DIR/complete"
tar czf "${TIMESTAMP}_complete_backup.tar.gz" "$TIMESTAMP"

if [ $? -eq 0 ]; then
    COMPRESSED_SIZE=$(du -h "${TIMESTAMP}_complete_backup.tar.gz" | cut -f1)
    log "✅ Backup compressed: ${TIMESTAMP}_complete_backup.tar.gz ($COMPRESSED_SIZE)"

    # Remove uncompressed directory to save space
    rm -rf "$TIMESTAMP"
else
    log "⚠️  Compression failed, keeping uncompressed backup"
fi

# 7. Cleanup old backups (keep last 7 days)
log "🧹 Cleaning up old backups..."
find "$BACKUP_BASE_DIR/complete" -name "*.tar.gz" -mtime +7 -delete 2>/dev/null || true
find "$BACKUP_BASE_DIR/complete" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true

# 8. Final summary
log "✅ Complete Infrastructure Backup Finished!"
log "📊 Backup Summary:"
log "   • Timestamp: $TIMESTAMP"
log "   • Location: $BACKUP_BASE_DIR/complete/"
log "   • Vault secrets: $([ -f "$BACKUP_DIR/vault/secrets.json" ] && echo "✅ Backed up" || echo "❌ Failed")"
log "   • Docker volumes: $(echo "$VOLUMES" | wc -l) volumes"
log "   • Total size: $(du -sh "$BACKUP_BASE_DIR/complete/${TIMESTAMP}_complete_backup.tar.gz" 2>/dev/null | cut -f1 || echo 'N/A')"

# Return status for Airflow
if [ -f "$BACKUP_BASE_DIR/complete/${TIMESTAMP}_complete_backup.tar.gz" ]; then
    echo "SUCCESS: Backup completed successfully"
    exit 0
else
    echo "ERROR: Backup failed"
    exit 1
fi
