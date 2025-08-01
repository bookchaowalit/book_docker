#!/bin/bash

# Docker Compose to Kubernetes Migration Tool
# Usage: ./docker-to-k8s.sh <docker-compose-path> [output-dir] [namespace]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NAMESPACE="default"
DEFAULT_OUTPUT_DIR="./k8s-output"

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
Usage: $0 <docker-compose-path> [output-dir] [namespace]

Arguments:
  docker-compose-path   Path to docker-compose.yml file or directory
  output-dir           Output directory for Kubernetes manifests (default: ./k8s-output)
  namespace            Kubernetes namespace (default: default)

Examples:
  $0 docker/applications/nocodb/docker-compose.yml
  $0 docker/applications/nocodb/ ./k8s/applications/ book-stack
  $0 docker/databases/postgres/docker-compose.yml ./k8s/databases/ databases

EOF
}

# Validate dependencies
check_dependencies() {
    local deps=("yq" "docker")
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
                docker) echo "  - docker: https://docs.docker.com/get-docker/" ;;
            esac
        done
        exit 1
    fi
}

# Parse Docker Compose file
parse_compose_file() {
    local compose_file="$1"
    
    if [[ ! -f "$compose_file" ]]; then
        log_error "Docker Compose file not found: $compose_file"
        exit 1
    fi
    
    log_info "Parsing Docker Compose file: $compose_file"
    
    # Validate compose file
    if ! docker compose -f "$compose_file" config &>/dev/null; then
        log_error "Invalid Docker Compose file: $compose_file"
        exit 1
    fi
}

# Convert service to Kubernetes manifests
convert_service() {
    local compose_file="$1"
    local service_name="$2"
    local output_dir="$3"
    local namespace="$4"
    
    log_info "Converting service: $service_name"
    
    # Extract service configuration
    local image=$(yq eval ".services.$service_name.image" "$compose_file")
    local container_name=$(yq eval ".services.$service_name.container_name // \"$service_name\"" "$compose_file")
    local restart_policy=$(yq eval ".services.$service_name.restart // \"no\"" "$compose_file")
    
    # Create output file
    local output_file="$output_dir/${service_name}.yaml"
    
    # Generate Kubernetes manifests
    cat > "$output_file" << EOF
# Generated from Docker Compose: $compose_file
# Service: $service_name
---
EOF

    # Generate ConfigMap if environment variables exist
    generate_configmap "$compose_file" "$service_name" "$namespace" >> "$output_file"
    
    # Generate PVC if volumes exist
    generate_pvc "$compose_file" "$service_name" "$namespace" >> "$output_file"
    
    # Generate Deployment
    generate_deployment "$compose_file" "$service_name" "$namespace" >> "$output_file"
    
    # Generate Service
    generate_service "$compose_file" "$service_name" "$namespace" >> "$output_file"
    
    # Generate Ingress if labels indicate Traefik usage
    generate_ingress "$compose_file" "$service_name" "$namespace" >> "$output_file"
    
    log_success "Generated Kubernetes manifest: $output_file"
}

# Generate ConfigMap for environment variables
generate_configmap() {
    local compose_file="$1"
    local service_name="$2"
    local namespace="$3"
    
    # Check if service has environment variables
    local env_vars=$(yq eval ".services.$service_name.environment // []" "$compose_file")
    local env_file=$(yq eval ".services.$service_name.env_file // []" "$compose_file")
    
    if [[ "$env_vars" != "[]" ]] || [[ "$env_file" != "[]" ]]; then
        cat << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${service_name}-config
  namespace: $namespace
data:
EOF
        
        # Process environment variables
        if [[ "$env_vars" != "[]" ]]; then
            yq eval ".services.$service_name.environment[]" "$compose_file" 2>/dev/null | while read -r env_var; do
                if [[ "$env_var" =~ ^([^=]+)=(.*)$ ]]; then
                    local key="${BASH_REMATCH[1]}"
                    local value="${BASH_REMATCH[2]}"
                    echo "  $key: \"$value\""
                fi
            done
        fi
        
        # Note about env_file
        if [[ "$env_file" != "[]" ]]; then
            echo "  # TODO: Manually convert env_file contents: $env_file"
        fi
        
        echo "---"
    fi
}

# Generate PersistentVolumeClaim for volumes
generate_pvc() {
    local compose_file="$1"
    local service_name="$2"
    local namespace="$3"
    
    # Check if service has volumes
    local volumes=$(yq eval ".services.$service_name.volumes // []" "$compose_file")
    
    if [[ "$volumes" != "[]" ]]; then
        cat << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${service_name}-pvc
  namespace: $namespace
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: fast-ssd
---
EOF
    fi
}

# Generate Deployment
generate_deployment() {
    local compose_file="$1"
    local service_name="$2"
    local namespace="$3"
    
    local image=$(yq eval ".services.$service_name.image" "$compose_file")
    local restart_policy=$(yq eval ".services.$service_name.restart // \"no\"" "$compose_file")
    
    # Convert restart policy
    local k8s_restart_policy="Always"
    case "$restart_policy" in
        "no"|"never") k8s_restart_policy="Never" ;;
        "on-failure") k8s_restart_policy="OnFailure" ;;
        *) k8s_restart_policy="Always" ;;
    esac
    
    cat << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $service_name
  namespace: $namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $service_name
  template:
    metadata:
      labels:
        app: $service_name
    spec:
      restartPolicy: $k8s_restart_policy
      containers:
      - name: $service_name
        image: $image
EOF

    # Add ports
    local ports=$(yq eval ".services.$service_name.ports // []" "$compose_file")
    if [[ "$ports" != "[]" ]]; then
        echo "        ports:"
        yq eval ".services.$service_name.ports[]" "$compose_file" | while read -r port_mapping; do
            if [[ "$port_mapping" =~ ^([0-9]+):([0-9]+)$ ]]; then
                local container_port="${BASH_REMATCH[2]}"
                echo "        - containerPort: $container_port"
                echo "          name: http"
            fi
        done
    fi
    
    # Add environment variables from ConfigMap
    local env_vars=$(yq eval ".services.$service_name.environment // []" "$compose_file")
    local env_file=$(yq eval ".services.$service_name.env_file // []" "$compose_file")
    
    if [[ "$env_vars" != "[]" ]] || [[ "$env_file" != "[]" ]]; then
        echo "        envFrom:"
        echo "        - configMapRef:"
        echo "            name: ${service_name}-config"
    fi
    
    # Add volume mounts
    local volumes=$(yq eval ".services.$service_name.volumes // []" "$compose_file")
    if [[ "$volumes" != "[]" ]]; then
        echo "        volumeMounts:"
        echo "        - name: ${service_name}-storage"
        echo "          mountPath: /data  # TODO: Adjust mount path as needed"
    fi
    
    # Add resource limits
    cat << EOF
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "1Gi"
            cpu: "500m"
EOF

    # Add volumes section
    if [[ "$volumes" != "[]" ]]; then
        cat << EOF
      volumes:
      - name: ${service_name}-storage
        persistentVolumeClaim:
          claimName: ${service_name}-pvc
EOF
    fi
    
    echo "---"
}

# Generate Service
generate_service() {
    local compose_file="$1"
    local service_name="$2"
    local namespace="$3"
    
    local ports=$(yq eval ".services.$service_name.ports // []" "$compose_file")
    
    if [[ "$ports" != "[]" ]]; then
        cat << EOF
apiVersion: v1
kind: Service
metadata:
  name: $service_name
  namespace: $namespace
spec:
  selector:
    app: $service_name
  ports:
EOF
        
        yq eval ".services.$service_name.ports[]" "$compose_file" | while read -r port_mapping; do
            if [[ "$port_mapping" =~ ^([0-9]+):([0-9]+)$ ]]; then
                local host_port="${BASH_REMATCH[1]}"
                local container_port="${BASH_REMATCH[2]}"
                cat << EOF
  - name: http
    port: $container_port
    targetPort: $container_port
EOF
            fi
        done
        
        echo "  type: ClusterIP"
        echo "---"
    fi
}

# Generate Ingress for Traefik labels
generate_ingress() {
    local compose_file="$1"
    local service_name="$2"
    local namespace="$3"
    
    # Check for Traefik labels
    local traefik_enabled=$(yq eval ".services.$service_name.labels[] | select(. == \"traefik.enable=true\")" "$compose_file" 2>/dev/null || echo "")
    
    if [[ -n "$traefik_enabled" ]]; then
        local host_rule=$(yq eval ".services.$service_name.labels[] | select(test(\"traefik.http.routers.*rule\"))" "$compose_file" 2>/dev/null | head -1 || echo "")
        
        if [[ -n "$host_rule" ]]; then
            # Extract hostname from rule
            local hostname=$(echo "$host_rule" | sed -n 's/.*Host(`\([^`]*\)`).*/\1/p')
            
            if [[ -n "$hostname" ]]; then
                cat << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${service_name}-ingress
  namespace: $namespace
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
  - host: $hostname
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $service_name
            port:
              number: 8080  # TODO: Adjust port as needed
---
EOF
            fi
        fi
    fi
}

# Main conversion function
convert_compose_to_k8s() {
    local compose_path="$1"
    local output_dir="$2"
    local namespace="$3"
    
    # Determine compose file path
    local compose_file
    if [[ -d "$compose_path" ]]; then
        compose_file="$compose_path/docker-compose.yml"
    else
        compose_file="$compose_path"
    fi
    
    parse_compose_file "$compose_file"
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Get all services from compose file
    local services=$(yq eval '.services | keys | .[]' "$compose_file")
    
    log_info "Found services: $(echo $services | tr '\n' ' ')"
    
    # Convert each service
    while IFS= read -r service; do
        convert_service "$compose_file" "$service" "$output_dir" "$namespace"
    done <<< "$services"
    
    # Generate namespace manifest
    cat > "$output_dir/namespace.yaml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $namespace
---
EOF
    
    log_success "Conversion completed! Kubernetes manifests generated in: $output_dir"
    log_warning "Please review and adjust the generated manifests as needed:"
    log_warning "- Verify resource limits and requests"
    log_warning "- Adjust volume mount paths"
    log_warning "- Review environment variable mappings"
    log_warning "- Configure ingress hostnames and paths"
}

# Main script
main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi
    
    local compose_path="$1"
    local output_dir="${2:-$DEFAULT_OUTPUT_DIR}"
    local namespace="${3:-$DEFAULT_NAMESPACE}"
    
    log_info "Starting Docker Compose to Kubernetes conversion"
    log_info "Source: $compose_path"
    log_info "Output: $output_dir"
    log_info "Namespace: $namespace"
    
    check_dependencies
    convert_compose_to_k8s "$compose_path" "$output_dir" "$namespace"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi