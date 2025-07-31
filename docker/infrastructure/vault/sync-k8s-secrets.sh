#!/bin/bash

# Kubernetes Vault integration script
# This script creates Kubernetes secrets from Vault

export VAULT_ADDR="http://vault.localhost"
export VAULT_TOKEN="myroot"

echo "☸️  Creating Kubernetes secrets from Vault..."

# Create namespace if it doesn't exist
kubectl create namespace book-monitoring --dry-run=client -o yaml | kubectl apply -f -

# Grafana secret from Vault
echo "📊 Creating Grafana secret..."
GRAFANA_USER=$(vault kv get -field=admin_user secret/k8s/grafana)
GRAFANA_PASSWORD=$(vault kv get -field=admin_password secret/k8s/grafana)

kubectl create secret generic grafana-secret \
  --from-literal=admin-user="$GRAFANA_USER" \
  --from-literal=admin-password="$GRAFANA_PASSWORD" \
  --namespace=book-monitoring \
  --dry-run=client -o yaml | kubectl apply -f -

# Database secrets for applications
echo "🗄️  Creating database secrets..."
kubectl create namespace book-stack --dry-run=client -o yaml | kubectl apply -f -

# PostgreSQL secret
POSTGRES_USER=$(vault kv get -field=username secret/database/postgres)
POSTGRES_PASSWORD=$(vault kv get -field=password secret/database/postgres)
POSTGRES_HOST=$(vault kv get -field=host secret/database/postgres)

kubectl create secret generic postgres-secret \
  --from-literal=username="$POSTGRES_USER" \
  --from-literal=password="$POSTGRES_PASSWORD" \
  --from-literal=host="$POSTGRES_HOST" \
  --namespace=book-stack \
  --dry-run=client -o yaml | kubectl apply -f -

# MySQL secret
MYSQL_ROOT_PASSWORD=$(vault kv get -field=root_password secret/database/mysql)
MYSQL_USER=$(vault kv get -field=username secret/database/mysql)
MYSQL_PASSWORD=$(vault kv get -field=password secret/database/mysql)

kubectl create secret generic mysql-secret \
  --from-literal=root-password="$MYSQL_ROOT_PASSWORD" \
  --from-literal=username="$MYSQL_USER" \
  --from-literal=password="$MYSQL_PASSWORD" \
  --namespace=book-stack \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Kubernetes secrets created from Vault!"
echo "📋 List of created secrets:"
kubectl get secrets -n book-monitoring
kubectl get secrets -n book-stack
