#!/bin/bash

# Book Stack Kubernetes Deployment Script
# This script deploys all services to Kubernetes following best practices

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Book Stack Kubernetes Deployment ===${NC}"

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}kubectl is not installed or not in PATH${NC}"
        exit 1
    fi
}

# Function to check if cluster is accessible
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Cannot connect to Kubernetes cluster${NC}"
        exit 1
    fi
}

# Function to apply manifests
apply_manifests() {
    local dir=$1
    local description=$2

    echo -e "${YELLOW}Deploying $description...${NC}"

    if [ -d "$dir" ]; then
        kubectl apply -f "$dir/"
        echo -e "${GREEN}✓ $description deployed${NC}"
    else
        echo -e "${RED}✗ Directory $dir not found${NC}"
    fi
}

# Function to wait for deployment
wait_for_deployment() {
    local namespace=$1
    local deployment=$2

    echo -e "${YELLOW}Waiting for $deployment in $namespace to be ready...${NC}"
    kubectl wait --for=condition=available --timeout=300s deployment/$deployment -n $namespace
    echo -e "${GREEN}✓ $deployment is ready${NC}"
}

# Function to wait for statefulset
wait_for_statefulset() {
    local namespace=$1
    local statefulset=$2

    echo -e "${YELLOW}Waiting for $statefulset in $namespace to be ready...${NC}"
    kubectl wait --for=jsonpath='{.status.readyReplicas}'=1 --timeout=300s statefulset/$statefulset -n $namespace
    echo -e "${GREEN}✓ $statefulset is ready${NC}"
}

# Main deployment function
main() {
    echo "Checking prerequisites..."
    check_kubectl
    check_cluster

    echo -e "${GREEN}Starting deployment...${NC}"

    # Deploy in order of dependencies
    apply_manifests "namespace" "Namespaces"
    sleep 2

    apply_manifests "storage" "Storage Classes"
    sleep 2

    apply_manifests "databases" "Database Services"
    sleep 5

    # Wait for databases to be ready
    echo -e "${YELLOW}Waiting for databases to be ready...${NC}"
    wait_for_statefulset "book-databases" "postgres"
    wait_for_statefulset "book-databases" "mysql"
    wait_for_statefulset "book-databases" "redis"

    apply_manifests "monitoring" "Monitoring Stack"
    sleep 5

    # Wait for monitoring to be ready
    wait_for_statefulset "book-monitoring" "prometheus"
    wait_for_deployment "book-monitoring" "grafana"

    apply_manifests "applications" "Application Services"
    sleep 5

    # Wait for applications to be ready
    wait_for_deployment "book-stack" "baserow"
    wait_for_deployment "book-stack" "nocodb"
    wait_for_deployment "book-stack" "open-webui"

    apply_manifests "ingress" "Ingress Controllers and Rules"

    echo -e "${GREEN}=== Deployment Complete ===${NC}"
    echo ""
    echo "Services are accessible at:"
    echo "- Grafana: http://grafana.yourdomain.com"
    echo "- Prometheus: http://prometheus.yourdomain.com"
    echo "- BaseRow: http://baserow.yourdomain.com"
    echo "- NocoDB: http://nocodb.yourdomain.com"
    echo "- Open WebUI: http://openwebui.yourdomain.com"
    echo ""
    echo "To check status: kubectl get pods --all-namespaces"
    echo "To view logs: kubectl logs -n <namespace> <pod-name>"
}

# Cleanup function
cleanup() {
    echo -e "${YELLOW}Cleaning up all resources...${NC}"

    kubectl delete -f ingress/ --ignore-not-found=true
    kubectl delete -f applications/ --ignore-not-found=true
    kubectl delete -f monitoring/ --ignore-not-found=true
    kubectl delete -f databases/ --ignore-not-found=true
    kubectl delete -f storage/ --ignore-not-found=true
    kubectl delete -f namespace/ --ignore-not-found=true

    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Check command line arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "cleanup")
        cleanup
        ;;
    "help")
        echo "Usage: $0 [deploy|cleanup|help]"
        echo "  deploy  - Deploy all services (default)"
        echo "  cleanup - Remove all deployed resources"
        echo "  help    - Show this help message"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Usage: $0 [deploy|cleanup|help]"
        exit 1
        ;;
esac
