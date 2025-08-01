#!/bin/bash

# Configuration Validation Tool
# Usage: ./validate-configs.sh [platform] [service-name]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="docker"
K8S_DIR="k8s"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [platform] [service-name]

Arguments:
  platform      Platform to validate (docker|k8s|both) (default: both)
  service-name  Optional: specific service to validate (default: all services)

Examples:
  $0                          # Validate all services on both platforms
  $0 docker                   # Validate all Docker services
  $0 k8s                      # Validate all Kubernetes services
  $0 both nocodb              # Validate nocodb service on both platforms
  $0 docker postgres          # Validate postgres Docker service only

EOF
}

# Validate dependencies
check_dependencies() {
    local deps=("yq" "docker" "kubectl")
    local missing=()
    local optional_missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            case $dep in
                "yq") missing+=("$dep") ;;
                "docker"|"kubectl") optional_missing+=("$dep") ;;
            esac
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing[*]}"
        exit 1
    fi
    
    if [ ${#optional_missing[@]} -ne 0 ]; then
        log_warning "Missing optional dependencies: ${optional_missing[*]}"
        log_warning "Some validation features may be limited"
    fi
}

# Validate Docker Compose file
validate_docker_compose() {
    local compose_file="$1"
    local service_name="$2"
    
    log_info "Validating Docker Compose: $compose_file"
    
    local errors=0
    local warnings=0
    
    # Check if file exists
    if [[ ! -f "$compose_file" ]]; then
        log_error "Docker Compose file not found: $compose_file"
        return 1
    fi
    
    # Validate YAML syntax
    if ! yq eval '.' "$compose_file" &>/dev/null; then
        log_error "Invalid YAML syntax in: $compose_file"
        ((errors++))
    fi
    
    # Check Docker Compose syntax if docker is available
    if command -v docker &>/dev/null; then
        if ! docker compose -f "$compose_file" config &>/dev/null; then
            log_error "Invalid Docker Compose syntax in: $compose_file"
            ((errors++))
        else
            log_success "Docker Compose syntax is valid"
        fi
    fi
    
    # Check for required fields
    local services=$(yq eval '.services | keys | .[]' "$compose_file" 2>/dev/null || echo "")
    if [[ -z "$services" ]]; then
        log_error "No services defined in: $compose_file"
        ((errors++))
    else
        log_info "Found services: $(echo $services | tr '\n' ' ')"
        
        # Validate each service
        while IFS= read -r service; do
            [[ -z "$service" ]] && continue
            [[ -n "$service_name" && "$service" != "$service_name" ]] && continue
            
            log_info "Validating service: $service"
            
            # Check for image
            local image=$(yq eval ".services.$service.image" "$compose_file" 2>/dev/null || echo "null")
            if [[ "$image" == "null" ]]; then
                log_warning "No image specified for service: $service"
                ((warnings++))
            fi
            
            # Check for container name conflicts
            local container_name=$(yq eval ".services.$service.container_name" "$compose_file" 2>/dev/null || echo "null")
            if [[ "$container_name" != "null" ]]; then
                # Check for duplicate container names in the same file
                local duplicate_count=$(yq eval ".services[].container_name" "$compose_file" 2>/dev/null | grep -c "^$container_name$" || echo "0")
                if [[ $duplicate_count -gt 1 ]]; then
                    log_error "Duplicate container name '$container_name' found in: $compose_file"
                    ((errors++))
                fi
            fi
            
            # Check for port conflicts
            local ports=$(yq eval ".services.$service.ports[]?" "$compose_file" 2>/dev/null || echo "")
            if [[ -n "$ports" ]]; then
                while IFS= read -r port_mapping; do
                    [[ -z "$port_mapping" ]] && continue
                    if [[ "$port_mapping" =~ ^([0-9]+):([0-9]+)$ ]]; then
                        local host_port="${BASH_REMATCH[1]}"
                        # Check for port conflicts within the same file
                        local port_count=$(yq eval '.services[].ports[]?' "$compose_file" 2>/dev/null | grep -c "^$host_port:" || echo "0")
                        if [[ $port_count -gt 1 ]]; then
                            log_error "Port conflict detected: $host_port is used multiple times in $compose_file"
                            ((errors++))
                        fi
                    fi
                done <<< "$ports"
            fi
            
            # Check for network configuration
            local networks=$(yq eval ".services.$service.networks[]?" "$compose_file" 2>/dev/null || echo "")
            if [[ -z "$networks" ]]; then
                log_warning "No networks specified for service: $service"
                ((warnings++))
            fi
            
            # Check for volume mounts
            local volumes=$(yq eval ".services.$service.volumes[]?" "$compose_file" 2>/dev/null || echo "")
            if [[ -n "$volumes" ]]; then
                while IFS= read -r volume; do
                    [[ -z "$volume" ]] && continue
                    # Check for bind mounts with non-existent paths
                    if [[ "$volume" =~ ^([^:]+):([^:]+) ]]; then
                        local host_path="${BASH_REMATCH[1]}"
                        if [[ "$host_path" =~ ^[./] ]]; then
                            local full_path="$(dirname "$compose_file")/$host_path"
                            if [[ ! -e "$full_path" ]]; then
                                log_warning "Bind mount source does not exist: $host_path (resolved to: $full_path)"
                                ((warnings++))
                            fi
                        fi
                    fi
                done <<< "$volumes"
            fi
            
        done <<< "$services"
    fi
    
    # Check for network definitions
    local networks=$(yq eval '.networks | keys | .[]?' "$compose_file" 2>/dev/null || echo "")
    if [[ -n "$networks" ]]; then
        log_info "Found networks: $(echo $networks | tr '\n' ' ')"
    fi
    
    # Check for volume definitions
    local volumes=$(yq eval '.volumes | keys | .[]?' "$compose_file" 2>/dev/null || echo "")
    if [[ -n "$volumes" ]]; then
        log_info "Found volumes: $(echo $volumes | tr '\n' ' ')"
    fi
    
    # Summary
    if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
        log_success "Docker Compose validation passed with no issues"
    elif [[ $errors -eq 0 ]]; then
        log_warning "Docker Compose validation passed with $warnings warnings"
    else
        log_error "Docker Compose validation failed with $errors errors and $warnings warnings"
    fi
    
    return $errors
}

# Validate Kubernetes manifest
validate_k8s_manifest() {
    local manifest_file="$1"
    local service_name="$2"
    
    log_info "Validating Kubernetes manifest: $manifest_file"
    
    local errors=0
    local warnings=0
    
    # Check if file exists
    if [[ ! -f "$manifest_file" ]]; then
        log_error "Kubernetes manifest file not found: $manifest_file"
        return 1
    fi
    
    # Validate YAML syntax
    if ! yq eval '.' "$manifest_file" &>/dev/null; then
        log_error "Invalid YAML syntax in: $manifest_file"
        ((errors++))
    fi
    
    # Check Kubernetes syntax if kubectl is available
    if command -v kubectl &>/dev/null; then
        if ! kubectl apply --dry-run=client -f "$manifest_file" &>/dev/null; then
            log_warning "Kubernetes manifest may have validation issues: $manifest_file"
            ((warnings++))
        else
            log_success "Kubernetes manifest syntax is valid"
        fi
    fi
    
    # Check for required Kubernetes resources
    local resources=$(yq eval '. | select(.kind != null) | .kind' "$manifest_file" 2>/dev/null || echo "")
    if [[ -z "$resources" ]]; then
        log_error "No Kubernetes resources found in: $manifest_file"
        ((errors++))
    else
        log_info "Found resources: $(echo $resources | tr '\n' ' ' | sort -u)"
        
        # Validate specific resource types
        local has_deployment=false
        local has_service=false
        local has_configmap=false
        
        while IFS= read -r resource; do
            [[ -z "$resource" ]] && continue
            
            case "$resource" in
                "Deployment")
                    has_deployment=true
                    validate_deployment "$manifest_file" "$service_name"
                    ;;
                "Service")
                    has_service=true
                    validate_service "$manifest_file" "$service_name"
                    ;;
                "ConfigMap")
                    has_configmap=true
                    validate_configmap "$manifest_file" "$service_name"
                    ;;
                "PersistentVolumeClaim")
                    validate_pvc "$manifest_file" "$service_name"
                    ;;
                "Ingress")
                    validate_ingress "$manifest_file" "$service_name"
                    ;;
            esac
        done <<< "$resources"
        
        # Check for common patterns
        if [[ "$has_deployment" == true && "$has_service" == false ]]; then
            log_warning "Deployment found but no Service defined - external access may be limited"
            ((warnings++))
        fi
    fi
    
    # Summary
    if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
        log_success "Kubernetes manifest validation passed with no issues"
    elif [[ $errors -eq 0 ]]; then
        log_warning "Kubernetes manifest validation passed with $warnings warnings"
    else
        log_error "Kubernetes manifest validation failed with $errors errors and $warnings warnings"
    fi
    
    return $errors
}

# Validate Deployment resource
validate_deployment() {
    local manifest_file="$1"
    local service_name="$2"
    
    # Check for required fields in Deployment
    local deployments=$(yq eval 'select(.kind == "Deployment") | .metadata.name' "$manifest_file" 2>/dev/null || echo "")
    
    while IFS= read -r deployment; do
        [[ -z "$deployment" ]] && continue
        [[ -n "$service_name" && "$deployment" != "$service_name" ]] && continue
        
        # Check for image
        local image=$(yq eval "select(.kind == \"Deployment\" and .metadata.name == \"$deployment\") | .spec.template.spec.containers[0].image" "$manifest_file" 2>/dev/null || echo "null")
        if [[ "$image" == "null" ]]; then
            log_error "No image specified for Deployment: $deployment"
        fi
        
        # Check for resource limits
        local resources=$(yq eval "select(.kind == \"Deployment\" and .metadata.name == \"$deployment\") | .spec.template.spec.containers[0].resources" "$manifest_file" 2>/dev/null || echo "null")
        if [[ "$resources" == "null" ]]; then
            log_warning "No resource limits specified for Deployment: $deployment"
        fi
        
        # Check for liveness/readiness probes
        local liveness=$(yq eval "select(.kind == \"Deployment\" and .metadata.name == \"$deployment\") | .spec.template.spec.containers[0].livenessProbe" "$manifest_file" 2>/dev/null || echo "null")
        local readiness=$(yq eval "select(.kind == \"Deployment\" and .metadata.name == \"$deployment\") | .spec.template.spec.containers[0].readinessProbe" "$manifest_file" 2>/dev/null || echo "null")
        
        if [[ "$liveness" == "null" ]]; then
            log_warning "No liveness probe specified for Deployment: $deployment"
        fi
        
        if [[ "$readiness" == "null" ]]; then
            log_warning "No readiness probe specified for Deployment: $deployment"
        fi
        
    done <<< "$deployments"
}

# Validate Service resource
validate_service() {
    local manifest_file="$1"
    local service_name="$2"
    
    local services=$(yq eval 'select(.kind == "Service") | .metadata.name' "$manifest_file" 2>/dev/null || echo "")
    
    while IFS= read -r service; do
        [[ -z "$service" ]] && continue
        [[ -n "$service_name" && "$service" != "$service_name" ]] && continue
        
        # Check for selector
        local selector=$(yq eval "select(.kind == \"Service\" and .metadata.name == \"$service\") | .spec.selector" "$manifest_file" 2>/dev/null || echo "null")
        if [[ "$selector" == "null" ]]; then
            log_error "No selector specified for Service: $service"
        fi
        
        # Check for ports
        local ports=$(yq eval "select(.kind == \"Service\" and .metadata.name == \"$service\") | .spec.ports" "$manifest_file" 2>/dev/null || echo "null")
        if [[ "$ports" == "null" ]]; then
            log_error "No ports specified for Service: $service"
        fi
        
    done <<< "$services"
}

# Validate ConfigMap resource
validate_configmap() {
    local manifest_file="$1"
    local service_name="$2"
    
    local configmaps=$(yq eval 'select(.kind == "ConfigMap") | .metadata.name' "$manifest_file" 2>/dev/null || echo "")
    
    while IFS= read -r configmap; do
        [[ -z "$configmap" ]] && continue
        
        # Check for data
        local data=$(yq eval "select(.kind == \"ConfigMap\" and .metadata.name == \"$configmap\") | .data" "$manifest_file" 2>/dev/null || echo "null")
        if [[ "$data" == "null" ]]; then
            log_warning "ConfigMap has no data: $configmap"
        fi
        
    done <<< "$configmaps"
}

# Validate PersistentVolumeClaim resource
validate_pvc() {
    local manifest_file="$1"
    local service_name="$2"
    
    local pvcs=$(yq eval 'select(.kind == "PersistentVolumeClaim") | .metadata.name' "$manifest_file" 2>/dev/null || echo "")
    
    while IFS= read -r pvc; do
        [[ -z "$pvc" ]] && continue
        
        # Check for storage request
        local storage=$(yq eval "select(.kind == \"PersistentVolumeClaim\" and .metadata.name == \"$pvc\") | .spec.resources.requests.storage" "$manifest_file" 2>/dev/null || echo "null")
        if [[ "$storage" == "null" ]]; then
            log_error "No storage request specified for PVC: $pvc"
        fi
        
    done <<< "$pvcs"
}

# Validate Ingress resource
validate_ingress() {
    local manifest_file="$1"
    local service_name="$2"
    
    local ingresses=$(yq eval 'select(.kind == "Ingress") | .metadata.name' "$manifest_file" 2>/dev/null || echo "")
    
    while IFS= read -r ingress; do
        [[ -z "$ingress" ]] && continue
        
        # Check for rules
        local rules=$(yq eval "select(.kind == \"Ingress\" and .metadata.name == \"$ingress\") | .spec.rules" "$manifest_file" 2>/dev/null || echo "null")
        if [[ "$rules" == "null" ]]; then
            log_error "No rules specified for Ingress: $ingress"
        fi
        
    done <<< "$ingresses"
}

# Find and validate all services
validate_all_services() {
    local platform="$1"
    local specific_service="$2"
    
    local categories=("applications" "databases" "infrastructure" "monitoring" "storage" "utilities")
    local total_errors=0
    local total_services=0
    
    for category in "${categories[@]}"; do
        log_info "Validating category: $category"
        
        if [[ "$platform" == "docker" || "$platform" == "both" ]]; then
            # Validate Docker services
            if [[ -d "$DOCKER_DIR/$category" ]]; then
                find "$DOCKER_DIR/$category" -name "docker-compose.yml" -type f | while read -r compose_file; do
                    local service_dir=$(dirname "$compose_file")
                    local service_name=$(basename "$service_dir")
                    
                    [[ -n "$specific_service" && "$service_name" != "$specific_service" ]] && continue
                    
                    ((total_services++))
                    if ! validate_docker_compose "$compose_file" "$specific_service"; then
                        ((total_errors++))
                    fi
                    echo "---"
                done
            fi
        fi
        
        if [[ "$platform" == "k8s" || "$platform" == "both" ]]; then
            # Validate Kubernetes services
            if [[ -d "$K8S_DIR/$category" ]]; then
                find "$K8S_DIR/$category" -name "*.yaml" -o -name "*.yml" | while read -r manifest_file; do
                    local service_name=$(basename "$manifest_file" .yaml)
                    service_name=$(basename "$service_name" .yml)
                    
                    [[ -n "$specific_service" && "$service_name" != "$specific_service" ]] && continue
                    
                    ((total_services++))
                    if ! validate_k8s_manifest "$manifest_file" "$specific_service"; then
                        ((total_errors++))
                    fi
                    echo "---"
                done
            fi
        fi
    done
    
    log_info "Validation Summary:"
    log_info "Total services validated: $total_services"
    log_info "Services with errors: $total_errors"
    
    return $total_errors
}

# Main function
main() {
    local platform="${1:-both}"
    local specific_service="${2:-}"
    
    # Validate input
    if [[ "$platform" != "docker" && "$platform" != "k8s" && "$platform" != "both" ]]; then
        log_error "Invalid platform: $platform (must be 'docker', 'k8s', or 'both')"
        exit 1
    fi
    
    check_dependencies
    
    log_info "Starting configuration validation"
    log_info "Platform: $platform"
    [[ -n "$specific_service" ]] && log_info "Service: $specific_service"
    
    validate_all_services "$platform" "$specific_service"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi