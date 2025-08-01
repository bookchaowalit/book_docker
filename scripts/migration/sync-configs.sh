#!/bin/bash

# Configuration Synchronization Tool
# Usage: ./sync-configs.sh <source-type> <target-type> [service-name]

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
Usage: $0 <source-type> <target-type> [service-name]

Arguments:
  source-type    Source deployment type (docker|k8s)
  target-type    Target deployment type (docker|k8s)
  service-name   Optional: specific service to sync (default: all services)

Examples:
  $0 docker k8s                    # Sync all Docker configs to Kubernetes
  $0 k8s docker                    # Sync all Kubernetes configs to Docker
  $0 docker k8s nocodb             # Sync only nocodb service
  $0 k8s docker postgres           # Sync only postgres service

EOF
}

# Validate dependencies
check_dependencies() {
    local deps=("yq" "jq")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        exit 1
    fi
}

# Find services in Docker directory
find_docker_services() {
    local category="$1"
    find "$DOCKER_DIR/$category" -name "docker-compose.yml" -type f 2>/dev/null | while read -r compose_file; do
        local service_dir=$(dirname "$compose_file")
        local service_name=$(basename "$service_dir")
        echo "$service_name|$compose_file"
    done
}

# Find services in Kubernetes directory
find_k8s_services() {
    local category="$1"
    find "$K8S_DIR/$category" -name "*.yaml" -o -name "*.yml" 2>/dev/null | while read -r manifest_file; do
        local service_name=$(basename "$manifest_file" .yaml)
        service_name=$(basename "$service_name" .yml)
        echo "$service_name|$manifest_file"
    done
}

# Extract environment variables from Docker Compose
extract_docker_env() {
    local compose_file="$1"
    local service_name="$2"
    
    # Extract environment variables
    yq eval ".services.$service_name.environment // [] | to_entries | .[] | .key + \"=\" + .value" "$compose_file" 2>/dev/null || true
    
    # Extract env_file references
    local env_files=$(yq eval ".services.$service_name.env_file // []" "$compose_file" 2>/dev/null)
    if [[ "$env_files" != "[]" && "$env_files" != "null" ]]; then
        yq eval ".services.$service_name.env_file[]" "$compose_file" 2>/dev/null | while read -r env_file; do
            local env_file_path=$(dirname "$compose_file")/"$env_file"
            if [[ -f "$env_file_path" ]]; then
                grep -v '^#' "$env_file_path" | grep -v '^$' || true
            fi
        done
    fi
}

# Extract environment variables from Kubernetes ConfigMap
extract_k8s_env() {
    local manifest_file="$1"
    local service_name="$2"
    
    # Look for ConfigMap with service name
    yq eval "select(.kind == \"ConfigMap\" and (.metadata.name | test(\"$service_name\"))) | .data | to_entries | .[] | .key + \"=\" + .value" "$manifest_file" 2>/dev/null || true
}

# Compare configurations between Docker and Kubernetes
compare_configs() {
    local docker_service="$1"
    local docker_file="$2"
    local k8s_service="$3"
    local k8s_file="$4"
    
    log_info "Comparing configurations for $docker_service (Docker) vs $k8s_service (Kubernetes)"
    
    # Create temporary files for comparison
    local docker_env_file=$(mktemp)
    local k8s_env_file=$(mktemp)
    
    # Extract environment variables
    extract_docker_env "$docker_file" "$docker_service" | sort > "$docker_env_file"
    extract_k8s_env "$k8s_file" "$k8s_service" | sort > "$k8s_env_file"
    
    # Compare configurations
    local differences=0
    
    # Check for variables in Docker but not in Kubernetes
    local docker_only=$(comm -23 "$docker_env_file" "$k8s_env_file")
    if [[ -n "$docker_only" ]]; then
        log_warning "Environment variables in Docker but not in Kubernetes:"
        echo "$docker_only" | sed 's/^/  /'
        differences=1
    fi
    
    # Check for variables in Kubernetes but not in Docker
    local k8s_only=$(comm -13 "$docker_env_file" "$k8s_env_file")
    if [[ -n "$k8s_only" ]]; then
        log_warning "Environment variables in Kubernetes but not in Docker:"
        echo "$k8s_only" | sed 's/^/  /'
        differences=1
    fi
    
    # Check for different values
    local common_vars=$(comm -12 "$docker_env_file" "$k8s_env_file")
    if [[ -n "$common_vars" ]]; then
        log_info "Common environment variables (values match):"
        echo "$common_vars" | sed 's/^/  /'
    fi
    
    # Cleanup
    rm -f "$docker_env_file" "$k8s_env_file"
    
    if [[ $differences -eq 0 ]]; then
        log_success "Configurations are synchronized"
    else
        log_warning "Configuration differences found"
    fi
    
    return $differences
}

# Sync environment variables from Docker to Kubernetes
sync_docker_to_k8s() {
    local docker_service="$1"
    local docker_file="$2"
    local k8s_service="$3"
    local k8s_file="$4"
    
    log_info "Syncing $docker_service (Docker) -> $k8s_service (Kubernetes)"
    
    # Extract Docker environment variables
    local docker_env=$(extract_docker_env "$docker_file" "$docker_service")
    
    if [[ -z "$docker_env" ]]; then
        log_warning "No environment variables found in Docker service: $docker_service"
        return 0
    fi
    
    # Create or update ConfigMap in Kubernetes manifest
    local configmap_name="${k8s_service}-config"
    local temp_file=$(mktemp)
    
    # Check if ConfigMap already exists
    if yq eval "select(.kind == \"ConfigMap\" and .metadata.name == \"$configmap_name\")" "$k8s_file" &>/dev/null; then
        log_info "Updating existing ConfigMap: $configmap_name"
        # Update existing ConfigMap
        cp "$k8s_file" "$temp_file"
        
        # Remove old data section and add new one
        yq eval "select(.kind == \"ConfigMap\" and .metadata.name == \"$configmap_name\") | .data = {}" "$temp_file" > "${temp_file}.tmp"
        mv "${temp_file}.tmp" "$temp_file"
        
        # Add environment variables
        while IFS= read -r env_var; do
            [[ -z "$env_var" ]] && continue
            local key=$(echo "$env_var" | cut -d'=' -f1)
            local value=$(echo "$env_var" | cut -d'=' -f2-)
            yq eval "select(.kind == \"ConfigMap\" and .metadata.name == \"$configmap_name\") | .data.\"$key\" = \"$value\"" -i "$temp_file"
        done <<< "$docker_env"
        
        # Replace original file
        cp "$temp_file" "$k8s_file"
    else
        log_info "Creating new ConfigMap: $configmap_name"
        # Add ConfigMap to the beginning of the file
        local namespace=$(yq eval 'select(.kind == "Deployment") | .metadata.namespace' "$k8s_file" 2>/dev/null || echo "default")
        
        cat > "$temp_file" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: $configmap_name
  namespace: $namespace
data:
EOF
        
        # Add environment variables
        while IFS= read -r env_var; do
            [[ -z "$env_var" ]] && continue
            local key=$(echo "$env_var" | cut -d'=' -f1)
            local value=$(echo "$env_var" | cut -d'=' -f2-)
            echo "  $key: \"$value\"" >> "$temp_file"
        done <<< "$docker_env"
        
        echo "---" >> "$temp_file"
        cat "$k8s_file" >> "$temp_file"
        cp "$temp_file" "$k8s_file"
    fi
    
    rm -f "$temp_file"
    log_success "Synchronized environment variables to Kubernetes ConfigMap"
}

# Sync environment variables from Kubernetes to Docker
sync_k8s_to_docker() {
    local k8s_service="$1"
    local k8s_file="$2"
    local docker_service="$3"
    local docker_file="$4"
    
    log_info "Syncing $k8s_service (Kubernetes) -> $docker_service (Docker)"
    
    # Extract Kubernetes environment variables
    local k8s_env=$(extract_k8s_env "$k8s_file" "$k8s_service")
    
    if [[ -z "$k8s_env" ]]; then
        log_warning "No environment variables found in Kubernetes service: $k8s_service"
        return 0
    fi
    
    # Create or update .env file
    local docker_dir=$(dirname "$docker_file")
    local env_file="$docker_dir/.env"
    
    log_info "Updating environment file: $env_file"
    
    # Backup existing .env file
    if [[ -f "$env_file" ]]; then
        cp "$env_file" "$env_file.backup.$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Create new .env file
    cat > "$env_file" << EOF
# Environment variables synchronized from Kubernetes
# Service: $k8s_service
# Generated on: $(date)

EOF
    
    # Add environment variables
    while IFS= read -r env_var; do
        [[ -z "$env_var" ]] && continue
        echo "$env_var" >> "$env_file"
    done <<< "$k8s_env"
    
    # Update docker-compose.yml to use .env file
    local temp_compose=$(mktemp)
    cp "$docker_file" "$temp_compose"
    
    # Check if env_file is already configured
    if ! yq eval ".services.$docker_service.env_file" "$docker_file" &>/dev/null; then
        yq eval ".services.$docker_service.env_file = [\"./.env\"]" -i "$temp_compose"
        cp "$temp_compose" "$docker_file"
        log_info "Added env_file reference to docker-compose.yml"
    fi
    
    rm -f "$temp_compose"
    log_success "Synchronized environment variables to Docker .env file"
}

# Main synchronization function
sync_configurations() {
    local source_type="$1"
    local target_type="$2"
    local specific_service="$3"
    
    if [[ "$source_type" == "$target_type" ]]; then
        log_error "Source and target types cannot be the same"
        exit 1
    fi
    
    local categories=("applications" "databases" "infrastructure" "monitoring" "storage" "utilities")
    local sync_count=0
    
    for category in "${categories[@]}"; do
        log_info "Processing category: $category"
        
        if [[ "$source_type" == "docker" ]]; then
            # Docker to Kubernetes sync
            find_docker_services "$category" | while IFS='|' read -r service_name docker_file; do
                [[ -n "$specific_service" && "$service_name" != "$specific_service" ]] && continue
                
                # Find corresponding Kubernetes service
                local k8s_file="$K8S_DIR/$category/${service_name}.yaml"
                if [[ ! -f "$k8s_file" ]]; then
                    k8s_file="$K8S_DIR/$category/${service_name}.yml"
                fi
                
                if [[ -f "$k8s_file" ]]; then
                    sync_docker_to_k8s "$service_name" "$docker_file" "$service_name" "$k8s_file"
                    ((sync_count++))
                else
                    log_warning "No corresponding Kubernetes manifest found for: $service_name"
                fi
            done
        else
            # Kubernetes to Docker sync
            find_k8s_services "$category" | while IFS='|' read -r service_name k8s_file; do
                [[ -n "$specific_service" && "$service_name" != "$specific_service" ]] && continue
                
                # Find corresponding Docker service
                local docker_file="$DOCKER_DIR/$category/${service_name}/docker-compose.yml"
                
                if [[ -f "$docker_file" ]]; then
                    sync_k8s_to_docker "$service_name" "$k8s_file" "$service_name" "$docker_file"
                    ((sync_count++))
                else
                    log_warning "No corresponding Docker Compose file found for: $service_name"
                fi
            done
        fi
    done
    
    log_success "Synchronization completed. Processed $sync_count services."
}

# Validate configurations across platforms
validate_configurations() {
    local specific_service="$1"
    
    log_info "Validating configurations across Docker and Kubernetes platforms"
    
    local categories=("applications" "databases" "infrastructure" "monitoring" "storage" "utilities")
    local total_services=0
    local synchronized_services=0
    
    for category in "${categories[@]}"; do
        log_info "Validating category: $category"
        
        find_docker_services "$category" | while IFS='|' read -r service_name docker_file; do
            [[ -n "$specific_service" && "$service_name" != "$specific_service" ]] && continue
            
            # Find corresponding Kubernetes service
            local k8s_file="$K8S_DIR/$category/${service_name}.yaml"
            if [[ ! -f "$k8s_file" ]]; then
                k8s_file="$K8S_DIR/$category/${service_name}.yml"
            fi
            
            if [[ -f "$k8s_file" ]]; then
                ((total_services++))
                if compare_configs "$service_name" "$docker_file" "$service_name" "$k8s_file"; then
                    ((synchronized_services++))
                fi
                echo "---"
            fi
        done
    done
    
    log_info "Validation Summary:"
    log_info "Total services validated: $total_services"
    log_info "Synchronized services: $synchronized_services"
    log_info "Services with differences: $((total_services - synchronized_services))"
}

# Main function
main() {
    if [[ $# -lt 2 ]]; then
        usage
        exit 1
    fi
    
    local source_type="$1"
    local target_type="$2"
    local specific_service="${3:-}"
    
    # Validate input
    if [[ "$source_type" != "docker" && "$source_type" != "k8s" ]]; then
        log_error "Invalid source type: $source_type (must be 'docker' or 'k8s')"
        exit 1
    fi
    
    if [[ "$target_type" != "docker" && "$target_type" != "k8s" ]]; then
        log_error "Invalid target type: $target_type (must be 'docker' or 'k8s')"
        exit 1
    fi
    
    check_dependencies
    
    # Special case for validation
    if [[ "$source_type" == "validate" ]]; then
        validate_configurations "$target_type"
        return
    fi
    
    log_info "Starting configuration synchronization"
    log_info "Source: $source_type"
    log_info "Target: $target_type"
    [[ -n "$specific_service" ]] && log_info "Service: $specific_service"
    
    sync_configurations "$source_type" "$target_type" "$specific_service"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi