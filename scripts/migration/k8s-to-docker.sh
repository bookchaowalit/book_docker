#!/bin/bash

# Kubernetes to Docker Compose Migration Tool
# Usage: ./k8s-to-docker.sh <k8s-manifest-path> [output-dir]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_OUTPUT_DIR="./docker-output"

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
Usage: $0 <k8s-manifest-path> [output-dir]

Arguments:
  k8s-manifest-path    Path to Kubernetes manifest file or directory
  output-dir          Output directory for Docker Compose files (default: ./docker-output)

Examples:
  $0 k8s/applications/nocodb.yaml
  $0 k8s/applications/ ./docker/applications/
  $0 k8s/databases/postgres.yaml ./docker/databases/

EOF
}

# Validate dependencies
check_dependencies() {
    local deps=("yq" "kubectl")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Please install missing dependencies:"
        for dep in "${missing[@]}"; do
            case $dep in
                yq) echo "  - yq: https://github.com/mikefarah/yq#install" ;;
                kubectl) echo "  - kubectl: https://kubernetes.io/docs/tasks/tools/" ;;
            esac
        done
        exit 1
    fi
}

# Parse Kubernetes manifest file
parse_k8s_manifest() {
    local manifest_file="$1"
    
    if [[ ! -f "$manifest_file" ]]; then
        log_error "Kubernetes manifest file not found: $manifest_file"
        exit 1
    fi
    
    log_info "Parsing Kubernetes manifest: $manifest_file"
    
    # Validate manifest file
    if ! kubectl apply --dry-run=client -f "$manifest_file" &>/dev/null; then
        log_warning "Kubernetes manifest may have validation issues: $manifest_file"
    fi
}

# Extract deployment information
extract_deployment_info() {
    local manifest_file="$1"
    local deployment_name="$2"
    
    # Extract deployment information using yq
    local image=$(yq eval "select(.kind == \"Deployment\" and .metadata.name == \"$deployment_name\") | .spec.template.spec.containers[0].image" "$manifest_file")
    local container_name=$(yq eval "select(.kind == \"Deployment\" and .metadata.name == \"$deployment_name\") | .spec.template.spec.containers[0].name" "$manifest_file")
    local namespace=$(yq eval "select(.kind == \"Deployment\" and .metadata.name == \"$deployment_name\") | .metadata.namespace" "$manifest_file")
    
    echo "$image|$container_name|$namespace"
}

# Extract service ports
extract_service_ports() {
    local manifest_file="$1"
    local service_name="$2"
    
    yq eval "select(.kind == \"Service\" and .metadata.name == \"$service_name\") | .spec.ports[].port" "$manifest_file" 2>/dev/null || echo ""
}

# Extract environment variables from ConfigMap
extract_configmap_env() {
    local manifest_file="$1"
    local configmap_name="$2"
    
    yq eval "select(.kind == \"ConfigMap\" and .metadata.name == \"$configmap_name\") | .data | to_entries | .[] | .key + \"=\" + .value" "$manifest_file" 2>/dev/null || echo ""
}

# Extract volume information
extract_volume_info() {
    local manifest_file="$1"
    local deployment_name="$2"
    
    # Check for PVC volumes
    local pvc_name=$(yq eval "select(.kind == \"Deployment\" and .metadata.name == \"$deployment_name\") | .spec.template.spec.volumes[]? | select(.persistentVolumeClaim) | .persistentVolumeClaim.claimName" "$manifest_file" 2>/dev/null || echo "")
    local mount_path=$(yq eval "select(.kind == \"Deployment\" and .metadata.name == \"$deployment_name\") | .spec.template.spec.containers[0].volumeMounts[]?.mountPath" "$manifest_file" 2>/dev/null || echo "")
    
    echo "$pvc_name|$mount_path"
}

# Extract ingress information
extract_ingress_info() {
    local manifest_file="$1"
    local service_name="$2"
    
    local hostname=$(yq eval "select(.kind == \"Ingress\") | .spec.rules[]? | select(.http.paths[].backend.service.name == \"$service_name\") | .host" "$manifest_file" 2>/dev/null || echo "")
    local path=$(yq eval "select(.kind == \"Ingress\") | .spec.rules[]? | select(.http.paths[].backend.service.name == \"$service_name\") | .http.paths[0].path" "$manifest_file" 2>/dev/null || echo "/")
    
    echo "$hostname|$path"
}

# Convert Kubernetes manifest to Docker Compose
convert_k8s_to_compose() {
    local manifest_file="$1"
    local output_dir="$2"
    
    # Get all deployments from the manifest
    local deployments=$(yq eval 'select(.kind == "Deployment") | .metadata.name' "$manifest_file" 2>/dev/null || echo "")
    
    if [[ -z "$deployments" ]]; then
        log_error "No Deployments found in manifest file: $manifest_file"
        exit 1
    fi
    
    log_info "Found deployments: $(echo $deployments | tr '\n' ' ')"
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Start building docker-compose.yml
    local compose_file="$output_dir/docker-compose.yml"
    
    cat > "$compose_file" << EOF
# Generated from Kubernetes manifest: $manifest_file
# Generated on: $(date)

services:
EOF

    # Process each deployment
    while IFS= read -r deployment; do
        [[ -z "$deployment" ]] && continue
        
        log_info "Converting deployment: $deployment"
        
        # Extract deployment information
        local deployment_info=$(extract_deployment_info "$manifest_file" "$deployment")
        IFS='|' read -r image container_name namespace <<< "$deployment_info"
        
        # Extract service ports
        local service_ports=$(extract_service_ports "$manifest_file" "$deployment")
        
        # Extract environment variables
        local configmap_name="${deployment}-config"
        local env_vars=$(extract_configmap_env "$manifest_file" "$configmap_name")
        
        # Extract volume information
        local volume_info=$(extract_volume_info "$manifest_file" "$deployment")
        IFS='|' read -r pvc_name mount_path <<< "$volume_info"
        
        # Extract ingress information
        local ingress_info=$(extract_ingress_info "$manifest_file" "$deployment")
        IFS='|' read -r hostname ingress_path <<< "$ingress_info"
        
        # Write service definition
        cat >> "$compose_file" << EOF

  $deployment:
    container_name: ${container_name:-$deployment}-container
    image: $image
EOF

        # Add ports if available
        if [[ -n "$service_ports" ]]; then
            echo "    ports:" >> "$compose_file"
            while IFS= read -r port; do
                [[ -z "$port" ]] && continue
                echo "      - \"$port:$port\"" >> "$compose_file"
            done <<< "$service_ports"
        fi
        
        # Add Traefik labels if ingress exists
        if [[ -n "$hostname" ]]; then
            cat >> "$compose_file" << EOF
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.$deployment.rule=Host(\`$hostname\`)"
      - "traefik.http.routers.$deployment.entrypoints=web"
      - "traefik.http.services.$deployment.loadbalancer.server.port=${service_ports:-8080}"
EOF
        fi
        
        # Add environment variables
        if [[ -n "$env_vars" ]]; then
            echo "    environment:" >> "$compose_file"
            while IFS= read -r env_var; do
                [[ -z "$env_var" ]] && continue
                echo "      - $env_var" >> "$compose_file"
            done <<< "$env_vars"
        fi
        
        # Add volumes if PVC exists
        if [[ -n "$pvc_name" && -n "$mount_path" ]]; then
            cat >> "$compose_file" << EOF
    volumes:
      - ${deployment}_data:$mount_path
EOF
        fi
        
        # Add restart policy and networks
        cat >> "$compose_file" << EOF
    restart: unless-stopped
    networks:
      - shared-networks
EOF
        
    done <<< "$deployments"
    
    # Add networks section
    cat >> "$compose_file" << EOF

networks:
  shared-networks:
    external: true
EOF
    
    # Add volumes section if any PVCs were found
    local has_volumes=$(yq eval 'select(.kind == "PersistentVolumeClaim") | .metadata.name' "$manifest_file" 2>/dev/null || echo "")
    if [[ -n "$has_volumes" ]]; then
        echo "" >> "$compose_file"
        echo "volumes:" >> "$compose_file"
        while IFS= read -r deployment; do
            [[ -z "$deployment" ]] && continue
            local volume_info=$(extract_volume_info "$manifest_file" "$deployment")
            IFS='|' read -r pvc_name mount_path <<< "$volume_info"
            if [[ -n "$pvc_name" ]]; then
                echo "  ${deployment}_data:" >> "$compose_file"
            fi
        done <<< "$deployments"
    fi
    
    # Create .env file template
    local env_file="$output_dir/.env"
    cat > "$env_file" << EOF
# Environment variables for Docker Compose
# Generated from Kubernetes manifest: $manifest_file

# TODO: Add environment-specific variables here
# Example:
# DATABASE_URL=postgresql://user:password@postgres:5432/dbname
# REDIS_URL=redis://redis:6379

EOF
    
    # Add extracted environment variables as comments
    while IFS= read -r deployment; do
        [[ -z "$deployment" ]] && continue
        local configmap_name="${deployment}-config"
        local env_vars=$(extract_configmap_env "$manifest_file" "$configmap_name")
        if [[ -n "$env_vars" ]]; then
            echo "# Environment variables from $deployment ConfigMap:" >> "$env_file"
            while IFS= read -r env_var; do
                [[ -z "$env_var" ]] && continue
                echo "# $env_var" >> "$env_file"
            done <<< "$env_vars"
            echo "" >> "$env_file"
        fi
    done <<< "$deployments"
    
    log_success "Generated Docker Compose file: $compose_file"
    log_success "Generated environment template: $env_file"
}

# Main conversion function
main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi
    
    local manifest_path="$1"
    local output_dir="${2:-$DEFAULT_OUTPUT_DIR}"
    
    log_info "Starting Kubernetes to Docker Compose conversion"
    log_info "Source: $manifest_path"
    log_info "Output: $output_dir"
    
    check_dependencies
    
    # Handle directory or single file
    if [[ -d "$manifest_path" ]]; then
        log_info "Processing directory: $manifest_path"
        for manifest_file in "$manifest_path"/*.yaml "$manifest_path"/*.yml; do
            [[ -f "$manifest_file" ]] || continue
            local service_name=$(basename "$manifest_file" .yaml)
            service_name=$(basename "$service_name" .yml)
            local service_output_dir="$output_dir/$service_name"
            
            parse_k8s_manifest "$manifest_file"
            convert_k8s_to_compose "$manifest_file" "$service_output_dir"
        done
    else
        parse_k8s_manifest "$manifest_path"
        convert_k8s_to_compose "$manifest_path" "$output_dir"
    fi
    
    log_success "Conversion completed!"
    log_warning "Please review and adjust the generated Docker Compose files:"
    log_warning "- Verify port mappings and networking"
    log_warning "- Update environment variables in .env files"
    log_warning "- Adjust volume mount paths as needed"
    log_warning "- Configure Traefik labels for ingress"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi