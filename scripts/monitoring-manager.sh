#!/bin/bash

# Monitoring Management Script
# Unified script to manage monitoring stack for both Docker and Kubernetes deployments

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_MONITORING_DIR="$PROJECT_ROOT/docker/monitoring"
K8S_MONITORING_DIR="$PROJECT_ROOT/k8s/monitoring"

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

# Function to show usage
show_usage() {
    cat << EOF
Monitoring Management Script

Usage: $0 [PLATFORM] [ACTION] [OPTIONS]

PLATFORMS:
    docker      - Manage Docker monitoring stack
    kubernetes  - Manage Kubernetes monitoring stack
    both        - Manage both platforms

ACTIONS:
    deploy      - Deploy monitoring stack
    status      - Show monitoring stack status
    stop        - Stop monitoring stack
    restart     - Restart monitoring stack
    logs        - Show logs for monitoring services
    health      - Check health of monitoring services
    config      - Validate monitoring configuration
    clean       - Clean up monitoring resources

OPTIONS:
    --service SERVICE   - Target specific service (prometheus, grafana, elk)
    --namespace NS      - Kubernetes namespace (default: monitoring)
    --help             - Show this help message

EXAMPLES:
    $0 docker deploy                    # Deploy Docker monitoring stack
    $0 kubernetes deploy               # Deploy Kubernetes monitoring stack
    $0 both status                     # Check status on both platforms
    $0 docker logs --service grafana   # Show Grafana logs in Docker
    $0 kubernetes health               # Check health in Kubernetes

EOF
}

# Function to validate prerequisites
validate_prerequisites() {
    local platform=$1
    
    case $platform in
        docker)
            if ! command -v docker &> /dev/null; then
                log_error "Docker is not installed or not in PATH"
                exit 1
            fi
            if ! command -v docker-compose &> /dev/null; then
                log_error "Docker Compose is not installed or not in PATH"
                exit 1
            fi
            ;;
        kubernetes)
            if ! command -v kubectl &> /dev/null; then
                log_error "kubectl is not installed or not in PATH"
                exit 1
            fi
            if ! kubectl cluster-info &> /dev/null; then
                log_error "No active Kubernetes cluster found"
                exit 1
            fi
            ;;
    esac
}

# Function to deploy Docker monitoring stack
deploy_docker_monitoring() {
    log_info "Deploying Docker monitoring stack..."
    
    # Ensure shared network exists
    if ! docker network ls | grep -q shared-networks; then
        log_info "Creating shared network..."
        docker network create shared-networks
        log_success "Shared network created"
    fi
    
    # Deploy monitoring services
    local services=("prometheus" "grafana" "elasticsearch-logstash-kibana")
    
    for service in "${services[@]}"; do
        if [[ -n "${TARGET_SERVICE:-}" && "$service" != "$TARGET_SERVICE" ]]; then
            continue
        fi
        
        log_info "Deploying $service..."
        cd "$DOCKER_MONITORING_DIR/$service"
        
        if docker-compose up -d; then
            log_success "$service deployed successfully"
        else
            log_error "Failed to deploy $service"
            return 1
        fi
    done
    
    log_info "Waiting for services to be ready..."
    sleep 30
    check_docker_health
}

# Function to deploy Kubernetes monitoring stack
deploy_kubernetes_monitoring() {
    log_info "Deploying Kubernetes monitoring stack..."
    
    local namespace="${NAMESPACE:-monitoring}"
    
    # Create namespace if it doesn't exist
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        log_info "Creating namespace: $namespace"
        kubectl create namespace "$namespace"
        log_success "Namespace $namespace created"
    fi
    
    # Create manifests if they don't exist
    if [[ ! -d "$K8S_MONITORING_DIR" ]]; then
        log_info "Creating Kubernetes monitoring manifests..."
        create_kubernetes_manifests "$namespace"
    fi
    
    # Deploy monitoring manifests
    log_info "Applying Kubernetes monitoring manifests..."
    kubectl apply -f "$K8S_MONITORING_DIR/" -n "$namespace"
    log_success "Kubernetes monitoring stack deployed"
    
    # Wait for deployments to be ready
    log_info "Waiting for deployments to be ready..."
    kubectl wait --for=condition=available deployment --all -n "$namespace" --timeout=300s
    log_success "All deployments are ready"
}

# Function to create basic Kubernetes monitoring manifests
create_kubernetes_manifests() {
    local namespace=$1
    
    mkdir -p "$K8S_MONITORING_DIR"
    
    # Create Prometheus manifest
    cat > "$K8S_MONITORING_DIR/prometheus.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  labels:
    app: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config-volume
          mountPath: /etc/prometheus
        - name: storage-volume
          mountPath: /prometheus
        args:
        - '--config.file=/etc/prometheus/prometheus.yml'
        - '--storage.tsdb.path=/prometheus'
        livenessProbe:
          httpGet:
            path: /-/healthy
            port: 9090
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /-/ready
            port: 9090
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: 256Mi
            cpu: 100m
          limits:
            memory: 512Mi
            cpu: 500m
      volumes:
      - name: config-volume
        configMap:
          name: prometheus-config
      - name: storage-volume
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  labels:
    app: prometheus
spec:
  selector:
    app: prometheus
  ports:
  - port: 9090
    targetPort: 9090
  type: ClusterIP
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    scrape_configs:
    - job_name: 'prometheus'
      static_configs:
      - targets: ['localhost:9090']
    - job_name: 'kubernetes-nodes'
      kubernetes_sd_configs:
      - role: node
EOF

    # Create Grafana manifest
    cat > "$K8S_MONITORING_DIR/grafana.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  labels:
    app: grafana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana-secret
              key: admin-password
        - name: GF_USERS_ALLOW_SIGN_UP
          value: "false"
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
        - name: grafana-datasources
          mountPath: /etc/grafana/provisioning/datasources
        livenessProbe:
          httpGet:
            path: /api/health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /api/health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: 256Mi
            cpu: 100m
          limits:
            memory: 512Mi
            cpu: 500m
      volumes:
      - name: grafana-storage
        emptyDir: {}
      - name: grafana-datasources
        configMap:
          name: grafana-datasources
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  labels:
    app: grafana
spec:
  selector:
    app: grafana
  ports:
  - port: 3000
    targetPort: 3000
  type: ClusterIP
---
apiVersion: v1
kind: Secret
metadata:
  name: grafana-secret
type: Opaque
data:
  admin-password: YWRtaW4xMjM=
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
data:
  prometheus.yaml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus:9090
      isDefault: true
      access: proxy
      editable: true
EOF

    log_success "Kubernetes monitoring manifests created"
}

# Function to check Docker monitoring health
check_docker_health() {
    log_info "Checking Docker monitoring stack health..."
    
    local healthy=true
    local services=("prometheus" "grafana")
    
    for service in "${services[@]}"; do
        if [[ -n "${TARGET_SERVICE:-}" && "$service" != "$TARGET_SERVICE" ]]; then
            continue
        fi
        
        local container_name="${service}-container"
        
        if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$container_name.*Up"; then
            log_success "$service is running"
        else
            log_error "$service is not running"
            healthy=false
        fi
    done
    
    if $healthy; then
        log_success "All monitoring services are healthy"
        return 0
    else
        log_error "Some monitoring services are unhealthy"
        return 1
    fi
}

# Function to check Kubernetes monitoring health 
check_kubernetes_health() {
    log_info "Checking Kubernetes monitoring stack health..."
    
    local namespace="${NAMESPACE:-monitoring}"
    local healthy=true
    
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        log_error "Namespace $namespace does not exist"
        return 1
    fi
    
    local deployments
    deployments=$(kubectl get deployments -n "$namespace" -o name 2>/dev/null || true)
    
    if [[ -z "$deployments" ]]; then
        log_warning "No monitoring deployments found in namespace $namespace"
        return 1
    fi
    
    for deployment in $deployments; do
        local dep_name
        dep_name=$(echo "$deployment" | cut -d'/' -f2)
        
        if [[ -n "${TARGET_SERVICE:-}" && "$dep_name" != "$TARGET_SERVICE" ]]; then
            continue
        fi
        
        local ready
        ready=$(kubectl get "$deployment" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired
        desired=$(kubectl get "$deployment" -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
        
        if [[ "$ready" == "$desired" ]] && [[ "$ready" -gt 0 ]]; then
            log_success "$dep_name deployment is ready ($ready/$desired)"
        else
            log_error "$dep_name deployment is not ready ($ready/$desired)"
            healthy=false
        fi
    done
    
    if $healthy; then
        log_success "All Kubernetes monitoring services are healthy"
        return 0
    else
        log_error "Some Kubernetes monitoring services are unhealthy"
        return 1
    fi
}

# Main function
main() {
    local platform=""
    local action=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            docker|kubernetes|both)
                platform=$1
                shift
                ;;
            deploy|status|stop|restart|logs|health|config|clean)
                action=$1
                shift
                ;;
            --service)
                TARGET_SERVICE=$2
                shift 2
                ;;
            --namespace)
                NAMESPACE=$2
                shift 2
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Validate arguments
    if [[ -z "$platform" || -z "$action" ]]; then
        log_error "Platform and action are required"
        show_usage
        exit 1
    fi
    
    # Execute action
    case $action in
        deploy)
            case $platform in
                docker)
                    validate_prerequisites docker
                    deploy_docker_monitoring
                    ;;
                kubernetes)
                    validate_prerequisites kubernetes
                    deploy_kubernetes_monitoring
                    ;;
                both)
                    validate_prerequisites docker
                    validate_prerequisites kubernetes
                    deploy_docker_monitoring
                    deploy_kubernetes_monitoring
                    ;;
            esac
            ;;
        health)
            case $platform in
                docker)
                    check_docker_health
                    ;;
                kubernetes)
                    check_kubernetes_health
                    ;;
                both)
                    check_docker_health
                    echo ""
                    check_kubernetes_health
                    ;;
            esac
            ;;
        *)
            log_error "Action $action not implemented yet"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"