#!/usr/bin/env bash

# Airflow entrypoint script
# Handles initialization and starts Airflow services

export AIRFLOW_HOME=/opt/airflow

case "$1" in
  webserver)
    echo "🌐 Starting Airflow Webserver..."
    # Install additional packages if needed
    pip install docker psycopg2-binary &>/dev/null || true

    # Initialize database
    airflow db init

    # Create admin user if it doesn't exist
    airflow users create \
        --username admin \
        --firstname admin \
        --lastname admin \
        --role Admin \
        --email admin@example.com \
        --password admin 2>/dev/null || echo "Admin user already exists"

    # Start webserver
    exec airflow webserver
    ;;
  scheduler)
    echo "📅 Starting Airflow Scheduler..."
    # Install additional packages if needed
    pip install docker psycopg2-binary &>/dev/null || true

    # Wait for webserver to initialize DB
    sleep 30

    # Start scheduler
    exec airflow scheduler
    ;;
  worker)
    echo "🔧 Starting Airflow Worker..."
    # Install additional packages if needed
    pip install docker psycopg2-binary &>/dev/null || true

    # Wait for scheduler to be ready
    sleep 60

    # Start worker
    exec airflow celery worker
    ;;
  flower)
    echo "🌸 Starting Airflow Flower..."
    # Wait for other services
    sleep 90

    # Start flower
    exec airflow celery flower
    ;;
  *)
    echo "❌ Unknown command: $1"
    echo "Available commands: webserver, scheduler, worker, flower"
    exit 1
    ;;
esac
