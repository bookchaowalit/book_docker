#!/bin/bash

# Kubernetes Security Scanning Script

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check RBAC configuration
check_rbac() {
    print_status "Checking RBAC configuration..."
    
    # Check for overly permissive cluster roles
    local cluster_admin_bindings=$(kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name')
    
    if [[ -n "$cluster_admin_bindings" ]]; then
        print_warning "Found cluster-admin bindings:"
        echo "$cluster_admin_bindings"
    fi
    
    # Check for default service account usage
    local default_sa_pods=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.serviceAccountName=="default" or .spec.serviceAccountName==null) | "\(.metadata.namespace)/\(.metadata.name)"')
    
    if [[ -n "$default_sa_pods" ]]; then
        print_warning "Pods using default service account:"
        echo "$default_sa_pods"
    fi
}

# Function to check pod security
check_pod_security() {
    print_status "Checking pod security configurations..."
    
    # Check for privileged pods
    local privileged_pods=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.securityContext.privileged==true or (.spec.containers[]?.securityContext.privileged==true)) | "\(.metadata.namespace)/\(.metadata.name)"')
    
    if [[ -n "$privileged_pods" ]]; then
        print_error "Found privileged pods:"
        echo "$privileged_pods"
    fi
    
    # Check for pods running as root
    local root_pods=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.securityContext.runAsUser==0 or (.spec.containers[]?.securityContext.runAsUser==0)) | "\(.metadata.namespace)/\(.metadata.name)"')
    
    if [[ -n "$root_pods" ]]; then
        print_warning "Found pods running as root:"
        echo "$root_pods"
    fi
    
    # Check for pods without resource limits
    local unlimited_pods=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[] | .resources.limits==null) | "\(.metadata.namespace)/\(.metadata.name)"')
    
    if [[ -n "$unlimited_pods" ]]; then
        print_warning "Found pods without resource limits:"
        echo "$unlimited_pods"
    fi
}

# Function to check network policies
check_network_policies() {
    print_status "Checking network policies..."
    
    local namespaces=$(kubectl get namespaces -o json | jq -r '.items[].metadata.name')
    
    for ns in $namespaces; do
        local policies=$(kubectl get networkpolicies -n "$ns" --no-headers 2>/dev/null | wc -l)
        if [[ $policies -eq 0 ]]; then
            print_warning "Namespace $ns has no network policies"
        else
            print_success "Namespace $ns has $policies network policies"
        fi
    done
}

# Function to check secrets
check_secrets() {
    print_status "Checking secrets configuration..."
    
    # Check for secrets in environment variables
    local env_secrets=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[]?.env[]?.valueFrom.secretKeyRef) | "\(.metadata.namespace)/\(.metadata.name)"')
    
    if [[ -n "$env_secrets" ]]; then
        print_success "Found pods using secrets from environment variables (good practice)"
    fi
    
    # Check for hardcoded secrets (basic check)
    local hardcoded_secrets=$(kubectl get configmaps --all-namespaces -o json | jq -r '.items[] | select(.data | to_entries[] | .value | test("password|secret|key|token"; "i")) | "\(.metadata.namespace)/\(.metadata.name)"')
    
    if [[ -n "$hardcoded_secrets" ]]; then
        print_error "Found potential hardcoded secrets in ConfigMaps:"
        echo "$hardcoded_secrets"
    fi
}

# Function to run all security checks
run_all_checks() {
    print_status "Running comprehensive security scan..."
    echo ""
    
    check_rbac
    echo ""
    check_pod_security
    echo ""
    check_network_policies
    echo ""
    check_secrets
    echo ""
    
    print_success "Security scan completed"
}

# Main execution
case "${1:-all}" in
    rbac)
        check_rbac
        ;;
    pods)
        check_pod_security
        ;;
    network)
        check_network_policies
        ;;
    secrets)
        check_secrets
        ;;
    all)
        run_all_checks
        ;;
    *)
        echo "Usage: $0 [rbac|pods|network|secrets|all]"
        exit 1
        ;;
esac
