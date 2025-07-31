"""
Apache Airflow DAG for Infrastructure Backup
Schedules daily backups of Vault secrets and Docker volumes
Runs inside Airflow Docker container
"""

import json
import os
from datetime import datetime, timedelta

from airflow.models import Variable
from airflow.operators.bash import BashOperator
from airflow.operators.email import EmailOperator
from airflow.operators.python import PythonOperator

from airflow import DAG

# Default arguments
default_args = {
    "owner": "infrastructure-team",
    "depends_on_past": False,
    "start_date": datetime(2025, 7, 27),
    "email_on_failure": True,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
    "email": ["admin@company.com"],  # Update with your email
}

# DAG definition
dag = DAG(
    "infrastructure_backup",
    default_args=default_args,
    description="Daily backup of Vault secrets and Docker volumes",
    schedule_interval="0 2 * * *",  # Daily at 2 AM
    catchup=False,
    tags=["backup", "infrastructure", "vault", "docker"],
)


# Python function to check backup results
def check_backup_status(**context):
    """Check if backup completed successfully and parse results"""
    import json
    import subprocess

    backup_dir = "/opt/airflow/book_docker/backups/complete"

    # Find the latest backup
    try:
        result = subprocess.run(
            f"ls -t {backup_dir}/*.tar.gz | head -1",
            shell=True,
            capture_output=True,
            text=True,
        )

        if result.returncode == 0 and result.stdout.strip():
            latest_backup = result.stdout.strip()
            backup_size = subprocess.run(
                f"du -h '{latest_backup}' | cut -f1",
                shell=True,
                capture_output=True,
                text=True,
            ).stdout.strip()

            context["task_instance"].xcom_push(key="backup_file", value=latest_backup)
            context["task_instance"].xcom_push(key="backup_size", value=backup_size)

            print(f"✅ Backup successful: {latest_backup} ({backup_size})")
            return True
        else:
            print("❌ No backup file found")
            return False

    except Exception as e:
        print(f"❌ Error checking backup: {str(e)}")
        return False


# Task 1: Pre-backup checks
pre_backup_check = BashOperator(
    task_id="pre_backup_check",
    bash_command="""
    echo "🔍 Running pre-backup checks..."

    # Check if Vault is running (from inside container)
    if ! curl -s http://vault.localhost/v1/sys/health > /dev/null; then
        echo "⚠️  Warning: Vault is not accessible"
    else
        echo "✅ Vault is accessible"
    fi

    # Check Docker (from inside container via socket)
    if ! docker info > /dev/null 2>&1; then
        echo "❌ Docker is not accessible"
        exit 1
    else
        echo "✅ Docker is accessible via socket"
    fi

    # Check disk space (require at least 5GB free)
    AVAILABLE=$(df /opt/airflow/book_docker/backups --output=avail | tail -1)
    if [ "$AVAILABLE" -lt 5242880 ]; then  # 5GB in KB
        echo "❌ Insufficient disk space for backup"
        exit 1
    else
        echo "✅ Sufficient disk space available"
    fi

    echo "✅ Pre-backup checks completed"
    """,
    dag=dag,
)

# Task 2: Run complete backup (from inside container)
run_backup = BashOperator(
    task_id="run_complete_backup",
    bash_command="""
    cd /opt/airflow/book_docker/vault

    # Set environment variables for Vault access
    export VAULT_ADDR="http://vault.localhost"
    export VAULT_TOKEN="myroot"

    # Make sure script is executable
    chmod +x complete-backup.sh

    # Run the backup
    ./complete-backup.sh
    """,
    dag=dag,
)

# Task 3: Verify backup
verify_backup = PythonOperator(
    task_id="verify_backup", python_callable=check_backup_status, dag=dag
)

# Task 4: Upload to remote storage (optional)
upload_to_remote = BashOperator(
    task_id="upload_to_remote_storage",
    bash_command="""
    # Example: Upload to S3, Google Cloud, or other remote storage
    # Uncomment and configure based on your storage solution

    # For AWS S3:
    # aws s3 cp {{ ti.xcom_pull(task_ids='verify_backup', key='backup_file') }} s3://your-backup-bucket/infrastructure/

    # For Google Cloud Storage:
    # gsutil cp {{ ti.xcom_pull(task_ids='verify_backup', key='backup_file') }} gs://your-backup-bucket/infrastructure/

    # For now, just move to a different directory
    BACKUP_FILE="{{ ti.xcom_pull(task_ids='verify_backup', key='backup_file') }}"
    if [ -n "$BACKUP_FILE" ]; then
        mkdir -p /opt/airflow/book_docker/backups/remote
        cp "$BACKUP_FILE" /opt/airflow/book_docker/backups/remote/
        echo "✅ Backup copied to remote directory"
    else
        echo "❌ No backup file to upload"
        exit 1
    fi
    """,
    dag=dag,
)

# Task 5: Cleanup old backups
cleanup_old_backups = BashOperator(
    task_id="cleanup_old_backups",
    bash_command="""
    echo "🧹 Cleaning up old backups..."

    # Keep last 30 days of backups
    find /opt/airflow/book_docker/backups/complete -name "*.tar.gz" -mtime +30 -delete 2>/dev/null || true
    find /opt/airflow/book_docker/backups/remote -name "*.tar.gz" -mtime +90 -delete 2>/dev/null || true

    echo "✅ Cleanup completed"
    """,
    dag=dag,
)

# Task 6: Send success notification
send_success_email = EmailOperator(
    task_id="send_success_notification",
    to=["admin@company.com"],  # Update with your email
    subject="✅ Infrastructure Backup Completed Successfully",
    html_content="""
    <h2>Infrastructure Backup Status: SUCCESS</h2>
    <p><strong>Backup completed at:</strong> {{ ds }} {{ ti.xcom_pull(task_ids='verify_backup', key='execution_date') }}</p>
    <p><strong>Backup file:</strong> {{ ti.xcom_pull(task_ids='verify_backup', key='backup_file') }}</p>
    <p><strong>Backup size:</strong> {{ ti.xcom_pull(task_ids='verify_backup', key='backup_size') }}</p>

    <h3>Components Backed Up:</h3>
    <ul>
        <li>✅ HashiCorp Vault secrets</li>
        <li>✅ Docker volumes</li>
        <li>✅ Configuration files</li>
    </ul>

    <p>All backups are stored securely and old backups have been cleaned up automatically.</p>

    <p><strong>Airflow UI:</strong> <a href="http://airflow.localhost">http://airflow.localhost</a></p>
    """,
    dag=dag,
    trigger_rule="all_success",
)

# Task 7: Send failure notification
send_failure_email = EmailOperator(
    task_id="send_failure_notification",
    to=["admin@company.com"],  # Update with your email
    subject="❌ Infrastructure Backup FAILED",
    html_content="""
    <h2>Infrastructure Backup Status: FAILED</h2>
    <p><strong>Failed at:</strong> {{ ds }}</p>
    <p><strong>Check the Airflow logs for details at:</strong> <a href="http://airflow.localhost">http://airflow.localhost</a></p>

    <h3>Recommended Actions:</h3>
    <ul>
        <li>Check if Vault is running: <code>docker ps | grep vault</code></li>
        <li>Check disk space: <code>df -h</code></li>
        <li>Check backup logs in Airflow UI</li>
        <li>Run manual backup: <code>cd /home/bookchaowalit/book/book_docker/vault && ./complete-backup.sh</code></li>
    </ul>
    """,
    dag=dag,
    trigger_rule="one_failed",
)

# Define task dependencies
(
    pre_backup_check
    >> run_backup
    >> verify_backup
    >> upload_to_remote
    >> cleanup_old_backups
    >> send_success_email
)
verify_backup >> send_failure_email
