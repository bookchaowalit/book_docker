#!/bin/bash

# Docker Volume Backup Script
# This script creates backups of all Docker volumes for disaster recovery

BACKUP_BASE_DIR="/home/bookchaowalit/book/book_docker/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_BASE_DIR/volumes/$TIMESTAMP"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "🗄️  Starting Docker Volume Backup - $TIMESTAMP"
echo "📁 Backup directory: $BACKUP_DIR"

# Function to backup a single volume
backup_volume() {
    local volume_name=$1
    local backup_file="$BACKUP_DIR/${volume_name}.tar.gz"

    echo "📦 Backing up volume: $volume_name"

    # Create backup using a temporary container
    docker run --rm \
        -v "$volume_name":/data:ro \
        -v "$BACKUP_DIR":/backup \
        alpine:latest \
        tar czf "/backup/${volume_name}.tar.gz" -C /data .

    if [ $? -eq 0 ]; then
        local size=$(du -h "$backup_file" | cut -f1)
        echo "✅ $volume_name backed up successfully ($size)"
    else
        echo "❌ Failed to backup $volume_name"
        return 1
    fi
}

# Get all named volumes (excluding anonymous ones)
VOLUMES=$(docker volume ls --format "{{.Name}}" | grep -E "^[a-zA-Z]")

# Backup each volume
for volume in $VOLUMES; do
    backup_volume "$volume"
done

# Create volume list metadata
echo "📝 Creating volume metadata..."
docker volume ls --format "table {{.Driver}}\t{{.Name}}\t{{.Scope}}" > "$BACKUP_DIR/volumes_list.txt"

# Create backup manifest
cat > "$BACKUP_DIR/backup_manifest.json" << EOF
{
  "backup_type": "docker_volumes",
  "timestamp": "$TIMESTAMP",
  "date": "$(date -Iseconds)",
  "volumes_count": $(echo "$VOLUMES" | wc -l),
  "volumes": [
$(echo "$VOLUMES" | sed 's/^/    "/' | sed 's/$/",/' | sed '$ s/,$//')
  ],
  "backup_size": "$(du -sh "$BACKUP_DIR" | cut -f1)"
}
EOF

echo ""
echo "✅ Docker Volume Backup Complete!"
echo "📊 Backup Summary:"
echo "   • Location: $BACKUP_DIR"
echo "   • Volumes backed up: $(echo "$VOLUMES" | wc -l)"
echo "   • Total size: $(du -sh "$BACKUP_DIR" | cut -f1)"
echo "   • Manifest: $BACKUP_DIR/backup_manifest.json"

# Cleanup old backups (keep last 7 days)
echo ""
echo "🧹 Cleaning up old backups (keeping last 7 days)..."
find "$BACKUP_BASE_DIR/volumes" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true

echo "🎉 Backup process completed successfully!"
