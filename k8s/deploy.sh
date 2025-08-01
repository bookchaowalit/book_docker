#!/bin/bash

# Enhanced Kubernetes Deployment Script
# This script provides comprehensive deployment management for Kubernetes services
# with category-based operations, health checking, and detailed status reporting

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/deployment.log"
TIMEOUT_SECONDS=300
RETRY_COUNT=3
RETRY_DELAY=5

# Service categories and their deployment order
declare -A CATEGORIES=(
    ["namespace"]="Namespace Definitions"
    ["storage"]="Storage Classes and Persistent Volumes"
    ["databases"]="Database Services"
    ["infrastructure"]="Core Infrastructure Services"
    ["monitoring"]="Monitoring and Observability Stack"
    ["applications"]="Application Services"
    ["ingress"]="Ingress Controllers and Rules"
    ["utilities"]="Utility Services"
)

# Category deployment order
DEPLOYMENT_ORDER=("namespace" "storage" "databases" "infrastructure" "monitoring" "applications" "ingress" "utilities")

echo -e "${GREEN}=== Enhanced Kubernetes Deployment Manager ===${NC}"

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case $level in
        "ERROR")
            echo -e "${RED}[$level] $message${NC}"
            ;;
        "WARN")
            echo -e "${YELLOW}[$level] $message${NC}"
            ;;
        "INFO")
            echo -e "${GREEN}[$level] $message${NC}"
            ;;
        "DEBUG")
            echo -e "${BLUE}[$level] $message${NC}"
            ;;
        *)
            echo "[$level] $message"
            ;;
    esac
}

# Function to check if kubectl is available
check_kubectl() {
    log "INFO" "Checking kubectl availability..."
    if ! command -v kubectl &> /dev/null; then
        log "ERROR" "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    local version=$(kubectl version --client --short 2>/dev/null | head -n1)
    log "INFO" "kubectl found: $version"
}

# Function to check if cluster is accessible
check_cluster() {
    log "INFO" "Checking cluster connectivity..."
    if ! kubectl cluster-info &> /dev/null; then
        log "ERROR" "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    local context=$(kubectl config current-context 2>/dev/null)
    log "INFO" "Connected to cluster context: $context"
}

# Function to validate manifest files
validate_manifests() {
    local dir=$1
    local valid=true
    
    if [ ! -d "$dir" ]; then
        log "WARN" "Directory $dir not found"
        return 1
    fi
    
    log "INFO" "Validating manifests in $dir..."
    
    for file in "$dir"/*.yaml "$dir"/*.yml; do
        if [ -f "$file" ]; then
            if ! kubectl apply --dry-run=client -f "$file" &>/dev/null; then
                log "ERROR" "Invalid manifest: $file"
                valid=false
            fi
        fi
    done
    
    if [ "$valid" = true ]; then
        log "INFO" "All manifests in $dir are valid"
        return 0
    else
        log "ERROR" "Some manifests in $dir are invalid"
        return 1
    fi
}

# Function to apply manifests with retry logic
apply_manifests() {
    local dir=$1
    local description=$2
    local retry_count=0
    
    log "INFO" "Starting deployment of $description from $dir"
    
    if [ ! -d "$dir" ]; then
        log "ERROR" "Directory $dir not found"
        return 1
    fi
    
    # Validate manifests first
    if ! validate_manifests "$dir"; then
        log "ERROR" "Manifest validation failed for $dir"
        return 1
    fi
    
    while [ $retry_count -lt $RETRY_COUNT ]; do
        log "INFO" "Applying manifests from $dir (attempt $((retry_count + 1))/$RETRY_COUNT)"
        
        if kubectl apply -f "$dir/" 2>&1 | tee -a "$LOG_FILE"; then
            log "INFO" "Successfully deployed $description"
            return 0
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $RETRY_COUNT ]; then
                log "WARN" "Deployment failed, retrying in $RETRY_DELAY seconds..."
                sleep $RETRY_DELAY
            else
                log "ERROR" "Failed to deploy $description after $RETRY_COUNT attempts"
                return 1
            fi
        fi
    done
}

# Function to wait for deployment with enhanced monitoring
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-$TIMEOUT_SECONDS}
    
    log "INFO" "Waiting for deployment $deployment in namespace $namespace"
    
    # Check if deployment exists
    if ! kubectl get deployment "$deployment" -n "$namespace" &>/dev/null; then
        log "ERROR" "Deployment $deployment not found in namespace $namespace"
        return 1
    fi
    
    # Wait for deployment to be available
    if kubectl wait --for=condition=available --timeout="${timeout}s" deployment/"$deployment" -n "$namespace" 2>&1 | tee -a "$LOG_FILE"; then
        log "INFO" "Deployment $deployment is ready"
        
        # Get deployment status
        local replicas=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.replicas}')
        local ready_replicas=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.readyReplicas}')
        log "INFO" "Deployment $deployment: $ready_replicas/$replicas replicas ready"
        
        return 0
    else
        log "ERROR" "Deployment $deployment failed to become ready within ${timeout}s"
        
        # Get pod status for debugging
        log "DEBUG" "Pod status for deployment $deployment:"
        kubectl get pods -n "$namespace" -l app="$deployment" -o wide 2>&1 | tee -a "$LOG_FILE"
        
        return 1
    fi
}

# Function to wait for statefulset with enhanced monitoring
wait_for_statefulset() {
    local namespace=$1
    local statefulset=$2
    local timeout=${3:-$TIMEOUT_SECONDS}
    
    log "INFO" "Waiting for statefulset $statefulset in namespace $namespace"
    
    # Check if statefulset exists
    if ! kubectl get statefulset "$statefulset" -n "$namespace" &>/dev/null; then
        log "ERROR" "StatefulSet $statefulset not found in namespace $namespace"
        return 1
    fi
    
    # Wait for statefulset to be ready
    if kubectl wait --for=jsonpath='{.status.readyReplicas}'=1 --timeout="${timeout}s" statefulset/"$statefulset" -n "$namespace" 2>&1 | tee -a "$LOG_FILE"; then
        log "INFO" "StatefulSet $statefulset is ready"
        
        # Get statefulset status
        local replicas=$(kubectl get statefulset "$statefulset" -n "$namespace" -o jsonpath='{.status.replicas}')
        local ready_replicas=$(kubectl get statefulset "$statefulset" -n "$namespace" -o jsonpath='{.status.readyReplicas}')
        log "INFO" "StatefulSet $statefulset: $ready_replicas/$replicas replicas ready"
        
        return 0
    else
        log "ERROR" "StatefulSet $statefulset failed to become ready within ${timeout}s"
        
        # Get pod status for debugging
        log "DEBUG" "Pod status for statefulset $statefulset:"
        kubectl get pods -n "$namespace" -l app="$statefulset" -o wide 2>&1 | tee -a "$LOG_FILE"
        
        return 1
    fi
}

# Function to get resource health status
get_resource_health() {
    local namespace=$1
    local resource_type=$2
    local resource_name=$3
    
    case $resource_type in
        "deployment")
            local desired=$(kubectl get deployment "$resource_name" -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
            local ready=$(kubectl get deployment "$resource_name" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            ;;
        "statefulset")
            local desired=$(kubectl get statefulset "$resource_name" -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
            local ready=$(kubectl get statefulset "$resource_name" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            ;;
        *)
            log "WARN" "Unknown resource type: $resource_type"
            return 1
            ;;
    esac
    
    if [ "$ready" = "$desired" ] && [ "$ready" != "0" ]; then
        echo "healthy"
    elif [ "$ready" = "0" ]; then
        echo "unhealthy"
    else
        echo "partial"
    fi
}

# Function to deploy specific category
deploy_category() {
    local category=$1
    local description="${CATEGORIES[$category]}"
    
    if [ -z "$description" ]; then
        log "ERROR" "Unknown category: $category"
        return 1
    fi
    
    log "INFO" "Deploying category: $category ($description)"
    
    if ! apply_manifests "$category" "$description"; then
        log "ERROR" "Failed to deploy category: $category"
        return 1
    fi
    
    # Wait for resources to be ready based on category
    case $category in
        "databases")
            sleep 5
            wait_for_category_resources "$category"
            ;;
        "monitoring")
            sleep 5
            wait_for_category_resources "$category"
            ;;
        "applications")
            sleep 5
            wait_for_category_resources "$category"
            ;;
        "infrastructure")
            sleep 3
            wait_for_category_resources "$category"
            ;;
        *)
            sleep 2
            ;;
    esac
    
    log "INFO" "Category $category deployment completed"
    return 0
}

# Function to wait for resources in a category
wait_for_category_resources() {
    local category=$1
    
    case $category in
        "databases")
            # Common database resources
            for resource in postgres mysql redis mongodb; do
                if kubectl get statefulset "$resource" -A &>/dev/null; then
                    local namespace=$(kubectl get statefulset "$resource" -A -o jsonpath='{.items[0].metadata.namespace}')
                    wait_for_statefulset "$namespace" "$resource" || log "WARN" "Failed to wait for $resource"
                fi
            done
            ;;
        "monitoring")
            # Common monitoring resources
            for resource in prometheus; do
                if kubectl get statefulset "$resource" -A &>/dev/null; then
                    local namespace=$(kubectl get statefulset "$resource" -A -o jsonpath='{.items[0].metadata.namespace}')
                    wait_for_statefulset "$namespace" "$resource" || log "WARN" "Failed to wait for $resource"
                fi
            done
            for resource in grafana; do
                if kubectl get deployment "$resource" -A &>/dev/null; then
                    local namespace=$(kubectl get deployment "$resource" -A -o jsonpath='{.items[0].metadata.namespace}')
                    wait_for_deployment "$namespace" "$resource" || log "WARN" "Failed to wait for $resource"
                fi
            done
            ;;
        "applications")
            # Common application resources
            for resource in baserow nocodb open-webui; do
                if kubectl get deployment "$resource" -A &>/dev/null; then
                    local namespace=$(kubectl get deployment "$resource" -A -o jsonpath='{.items[0].metadata.namespace}')
                    wait_for_deployment "$namespace" "$resource" || log "WARN" "Failed to wait for $resource"
                fi
            done
            ;;
        "infrastructure")
            # Infrastructure resources - typically don't need specific waiting
            log "INFO" "Infrastructure resources deployed, no specific waiting required"
            ;;
    esac
}

# Function to show deployment status
show_status() {
    log "INFO" "Showing deployment status..."
    
    echo -e "\n${CYAN}=== Deployment Status ===${NC}"
    
    for category in "${DEPLOYMENT_ORDER[@]}"; do
        if [ -d "$category" ]; then
            echo -e "\n${YELLOW}Category: $category (${CATEGORIES[$category]})${NC}"
            
            # Get all resources in this category
            local resources_found=false
            
            # Check for deployments
            while IFS= read -r line; do
                if [ -n "$line" ]; then
                    resources_found=true
                    local namespace=$(echo "$line" | awk '{print $1}')
                    local name=$(echo "$line" | awk '{print $2}')
                    local health=$(get_resource_health "$namespace" "deployment" "$name")
                    
                    case $health in
                        "healthy")
                            echo -e "  ${GREEN}✓${NC} Deployment $namespace/$name: $health"
                            ;;
                        "unhealthy")
                            echo -e "  ${RED}✗${NC} Deployment $namespace/$name: $health"
                            ;;
                        "partial")
                            echo -e "  ${YELLOW}⚠${NC} Deployment $namespace/$name: $health"
                            ;;
                    esac
                fi
            done < <(kubectl get deployments -A --no-headers 2>/dev/null | grep -E "($(echo "$category" | tr '[:lower:]' '[:upper:]'))" || true)
            
            # Check for statefulsets
            while IFS= read -r line; do
                if [ -n "$line" ]; then
                    resources_found=true
                    local namespace=$(echo "$line" | awk '{print $1}')
                    local name=$(echo "$line" | awk '{print $2}')
                    local health=$(get_resource_health "$namespace" "statefulset" "$name")
                    
                    case $health in
                        "healthy")
                            echo -e "  ${GREEN}✓${NC} StatefulSet $namespace/$name: $health"
                            ;;
                        "unhealthy")
                            echo -e "  ${RED}✗${NC} StatefulSet $namespace/$name: $health"
                            ;;
                        "partial")
                            echo -e "  ${YELLOW}⚠${NC} StatefulSet $namespace/$name: $health"
                            ;;
                    esac
                fi
            done < <(kubectl get statefulsets -A --no-headers 2>/dev/null | grep -E "($(echo "$category" | tr '[:lower:]' '[:upper:]'))" || true)
            
            if [ "$resources_found" = false ]; then
                echo -e "  ${BLUE}ℹ${NC} No resources found for this category"
            fi
        else
            echo -e "\n${YELLOW}Category: $category${NC}"
            echo -e "  ${BLUE}ℹ${NC} Directory not found"
        fi
    done
    
    echo -e "\n${CYAN}=== Overall Cluster Status ===${NC}"
    kubectl get nodes --no-headers 2>/dev/null | while read -r line; do
        local node_name=$(echo "$line" | awk '{print $1}')
        local node_status=$(echo "$line" | awk '{print $2}')
        
        if [ "$node_status" = "Ready" ]; then
            echo -e "  ${GREEN}✓${NC} Node $node_name: $node_status"
        else
            echo -e "  ${RED}✗${NC} Node $node_name: $node_status"
        fi
    done
}

# Main deployment function
deploy_all() {
    log "INFO" "Starting full deployment..."
    
    local failed_categories=()
    
    for category in "${DEPLOYMENT_ORDER[@]}"; do
        if [ -d "$category" ]; then
            if ! deploy_category "$category"; then
                failed_categories+=("$category")
                log "ERROR" "Failed to deploy category: $category"
                
                # Ask user if they want to continue
                echo -e "${YELLOW}Category $category failed. Continue with remaining categories? (y/n)${NC}"
                read -r continue_choice
                if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
                    log "INFO" "Deployment stopped by user"
                    return 1
                fi
            fi
        else
            log "WARN" "Category directory not found: $category"
        fi
    done
    
    if [ ${#failed_categories[@]} -eq 0 ]; then
        log "INFO" "All categories deployed successfully"
        show_deployment_summary
        return 0
    else
        log "WARN" "Deployment completed with failures in: ${failed_categories[*]}"
        show_deployment_summary
        return 1
    fi
}

# Function to show deployment summary
show_deployment_summary() {
    echo -e "\n${GREEN}=== Deployment Summary ===${NC}"
    echo ""
    echo "Services may be accessible at:"
    echo "- Grafana: http://grafana.yourdomain.com"
    echo "- Prometheus: http://prometheus.yourdomain.com"
    echo "- BaseRow: http://baserow.yourdomain.com"
    echo "- NocoDB: http://nocodb.yourdomain.com"
    echo "- Open WebUI: http://openwebui.yourdomain.com"
    echo ""
    echo "Useful commands:"
    echo "  Check status: $0 status"
    echo "  View all pods: kubectl get pods --all-namespaces"
    echo "  View logs: kubectl logs -n <namespace> <pod-name>"
    echo "  Port forward: kubectl port-forward -n <namespace> <pod-name> <local-port>:<pod-port>"
    echo ""
    echo "Log file: $LOG_FILE"
}

# Enhanced cleanup function
cleanup() {
    local category=$1
    
    log "INFO" "Starting cleanup process..."
    
    if [ -n "$category" ]; then
        # Clean up specific category
        if [ -z "${CATEGORIES[$category]}" ]; then
            log "ERROR" "Unknown category: $category"
            return 1
        fi
        
        log "INFO" "Cleaning up category: $category"
        if [ -d "$category" ]; then
            kubectl delete -f "$category/" --ignore-not-found=true 2>&1 | tee -a "$LOG_FILE"
            log "INFO" "Category $category cleanup completed"
        else
            log "WARN" "Category directory not found: $category"
        fi
    else
        # Clean up all resources in reverse order
        log "INFO" "Cleaning up all resources..."
        
        local reverse_order=()
        for ((i=${#DEPLOYMENT_ORDER[@]}-1; i>=0; i--)); do
            reverse_order+=("${DEPLOYMENT_ORDER[i]}")
        done
        
        for category in "${reverse_order[@]}"; do
            if [ -d "$category" ]; then
                log "INFO" "Cleaning up category: $category"
                kubectl delete -f "$category/" --ignore-not-found=true 2>&1 | tee -a "$LOG_FILE"
                sleep 2
            fi
        done
        
        log "INFO" "Full cleanup completed"
    fi
}

# Function to list available categories
list_categories() {
    echo -e "\n${CYAN}=== Available Categories ===${NC}"
    
    for category in "${DEPLOYMENT_ORDER[@]}"; do
        local description="${CATEGORIES[$category]}"
        if [ -d "$category" ]; then
            echo -e "  ${GREEN}✓${NC} $category - $description"
        else
            echo -e "  ${YELLOW}⚠${NC} $category - $description (directory not found)"
        fi
    done
    
    echo -e "\n${BLUE}Usage examples:${NC}"
    echo "  $0 deploy databases          # Deploy only databases"
    echo "  $0 cleanup applications      # Cleanup only applications"
    echo "  $0 status                    # Show deployment status"
}

# Function to show help
show_help() {
    echo -e "\n${CYAN}=== Enhanced Kubernetes Deployment Manager ===${NC}"
    echo ""
    echo "Usage: $0 [COMMAND] [CATEGORY]"
    echo ""
    echo "Commands:"
    echo "  deploy [category]    Deploy all services or specific category (default)"
    echo "  cleanup [category]   Remove all resources or specific category"
    echo "  status              Show deployment status"
    echo "  categories          List available categories"
    echo "  help                Show this help message"
    echo ""
    echo "Categories:"
    for category in "${DEPLOYMENT_ORDER[@]}"; do
        echo "  $category"
    done
    echo ""
    echo "Examples:"
    echo "  $0                          # Deploy all categories"
    echo "  $0 deploy                   # Deploy all categories"
    echo "  $0 deploy databases         # Deploy only databases"
    echo "  $0 cleanup                  # Cleanup all resources"
    echo "  $0 cleanup applications     # Cleanup only applications"
    echo "  $0 status                   # Show current status"
    echo ""
    echo "Log file: $LOG_FILE"
}

# Main execution logic
main() {
    # Initialize log file
    echo "=== Kubernetes Deployment Manager Started at $(date) ===" > "$LOG_FILE"
    
    local command="${1:-deploy}"
    local category="$2"
    
    # Commands that don't require cluster connectivity
    case "$command" in
        "help")
            show_help
            return 0
            ;;
        "categories")
            list_categories
            return 0
            ;;
    esac
    
    # For other commands, check prerequisites
    log "INFO" "Checking prerequisites..."
    check_kubectl
    check_cluster
    
    case "$command" in
        "deploy")
            if [ -n "$category" ]; then
                # Deploy specific category
                if [ -z "${CATEGORIES[$category]}" ]; then
                    log "ERROR" "Unknown category: $category"
                    list_categories
                    exit 1
                fi
                deploy_category "$category"
            else
                # Deploy all categories
                deploy_all
            fi
            ;;
        "cleanup")
            cleanup "$category"
            ;;
        "status")
            show_status
            ;;
        "categories")
            list_categories
            ;;
        "help")
            show_help
            ;;
        *)
            log "ERROR" "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
