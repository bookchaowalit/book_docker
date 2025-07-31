#!/bin/bash

# Cron-based backup scheduler
# Alternative to Airflow for automated backups

# Add this to your crontab with: crontab -e
# 0 2 * * * /home/bookchaowalit/book/book_docker/vault/cron-backup.sh >> /var/log/backup.log 2>&1

LOG_FILE="/var/log/backup.log"
EMAIL="admin@company.com"  # Update with your email

echo "$(date): Starting scheduled infrastructure backup" >> $LOG_FILE

cd /home/bookchaowalit/book/book_docker/vault

# Run complete backup
if ./vault-manager.sh backup-complete; then
    echo "$(date): Backup completed successfully" >> $LOG_FILE

    # Send success email (requires mailutils)
    if command -v mail > /dev/null; then
        echo "Infrastructure backup completed successfully at $(date)" | mail -s "✅ Backup Success" $EMAIL
    fi
else
    echo "$(date): Backup failed" >> $LOG_FILE

    # Send failure email
    if command -v mail > /dev/null; then
        echo "Infrastructure backup FAILED at $(date). Check logs at $LOG_FILE" | mail -s "❌ Backup Failed" $EMAIL
    fi
fi

echo "$(date): Backup process finished" >> $LOG_FILE
