#!/bin/bash

# Kubernetes Network Setup Script
# This script creates and manages Kubernetes network policies and configurations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Namespace configurations
NAMESPACES=("book-stack" "book-monitoring" "book-databases" "book-infrastructure" "book-security")

# Function to print colored output
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

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
}

# Function to create namespaces
create_namespaces() {
    print_status "Creating Kubernetes namespaces..."
    
    for namespace in "${NAMESPACES[@]}"; do
        if kubectl get namespace "$namespace" &> /dev/null; then
            print_warning "Namespace $namespace already exists"
        else
            kubectl create namespace "$namespace"
            print_success "Created namespace: $namespace"
        fi
        
        # Label namespaces for network policies
        kubectl label namespace "$namespace" name="$namespace" --overwrite
    done
}

# Function to create network policies
create_network_policies() {
    print_status "Creating network policies..."
    
    # Create network policies directory if it doesn't exist
    mkdir -p k8s/networking
    
    # Default deny all ingress policy template
    cat > k8s/networking/default-deny-ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF

    # Database access policy - only allow from applications and monitoring
    cat > k8s/networking/database-access-policy.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-access-policy
  namespace: book-databases
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: book-stack
    - namespaceSelector:
        matchLabels:
          name: book-monitoring
    ports:
    - protocol: TCP
      port: 5432  # PostgreSQL
    - protocol: TCP
      port: 3306  # MySQL
    - protocol: TCP
      port: 6379  # Redis
    - protocol: TCP
      port: 27017 # MongoDB
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 53    # DNS
    - protocol: UDP
      port: 53    # DNS
EOF

    # Application network policy - allow ingress from ingress controller
    cat > k8s/networking/application-access-policy.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: application-access-policy
  namespace: book-stack
spec:
  podSelector:
    matchLabels:
      tier: application
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
  - from:
    - namespaceSelector:
        matchLabels:
          name: book-monitoring
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 3000
    - protocol: TCP
      port: 9090
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: book-databases
  - to: []
    ports:
    - protocol: TCP
      port: 53    # DNS
    - protocol: UDP
      port: 53    # DNS
    - protocol: TCP
      port: 443   # HTTPS
    - protocol: TCP
      port: 80    # HTTP
EOF

    # Monitoring network policy - allow access to all namespaces for metrics collection
    cat > k8s/networking/monitoring-access-policy.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: monitoring-access-policy
  namespace: book-monitoring
spec:
  podSelector:
    matchLabels:
      tier: monitoring
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
  - from:
    - namespaceSelector:
        matchLabels:
          name: book-stack
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: book-stack
  - to:
    - namespaceSelector:
        matchLabels:
          name: book-databases
  - to:
    - namespaceSelector:
        matchLabels:
          name: book-infrastructure
  - to: []
    ports:
    - protocol: TCP
      port: 53    # DNS
    - protocol: UDP
      port: 53    # DNS
    - protocol: TCP
      port: 443   # HTTPS
    - protocol: TCP
      port: 80    # HTTP
EOF

    # Security services policy - restricted access
    cat > k8s/networking/security-access-policy.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: security-access-policy
  namespace: book-security
spec:
  podSelector:
    matchLabels:
      tier: security
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: book-stack
    - namespaceSelector:
        matchLabels:
          name: book-infrastructure
    ports:
    - protocol: TCP
      port: 8200  # Vault
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 53    # DNS
    - protocol: UDP
      port: 53    # DNS
    - protocol: TCP
      port: 443   # HTTPS
EOF

    print_success "Network policy templates created"
}

# Function to apply network policies
apply_network_policies() {
    print_status "Applying network policies..."
    
    # Apply default deny policies to each namespace
    for namespace in "${NAMESPACES[@]}"; do
        kubectl apply -f k8s/networking/default-deny-ingress.yaml -n "$namespace"
        print_success "Applied default deny policy to $namespace"
    done
    
    # Apply specific policies
    kubectl apply -f k8s/networking/database-access-policy.yaml
    kubectl apply -f k8s/networking/application-access-policy.yaml
    kubectl apply -f k8s/networking/monitoring-access-policy.yaml
    kubectl apply -f k8s/networking/security-access-policy.yaml
    
    print_success "All network policies applied"
}

# Function to create service mesh configuration (Istio-ready)
create_service_mesh_config() {
    print_status "Creating service mesh configuration..."
    
    mkdir -p k8s/networking/service-mesh
    
    # Istio sidecar injection configuration
    cat > k8s/networking/service-mesh/sidecar-injection.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio-sidecar-injector
  namespace: istio-system
data:
  config: |
    policy: enabled
    alwaysInjectSelector:
      []
    neverInjectSelector:
      - matchExpressions:
        - {key: openshift.io/build.name, operator: Exists}
      - matchExpressions:
        - {key: openshift.io/deployer-pod-for.name, operator: Exists}
    template: |
      rewriteAppHTTPProbe: true
      initContainers:
      - name: istio-init
        image: docker.io/istio/proxyv2:1.19.0
        args:
        - istio-iptables
        - -p
        - "15001"
        - -z
        - "15006"
        - -u
        - "1337"
        - -m
        - REDIRECT
        - -i
        - '*'
        - -x
        - ""
        - -b
        - '*'
        - -d
        - 15090,15021,15020
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            add:
            - NET_ADMIN
            - NET_RAW
            drop:
            - ALL
          privileged: false
          readOnlyRootFilesystem: false
          runAsGroup: 0
          runAsNonRoot: false
          runAsUser: 0
EOF

    # Virtual service template for applications
    cat > k8s/networking/service-mesh/virtual-service-template.yaml << 'EOF'
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: application-vs
  namespace: book-stack
spec:
  hosts:
  - "*.yourdomain.com"
  gateways:
  - book-gateway
  http:
  - match:
    - headers:
        host:
          exact: baserow.yourdomain.com
    route:
    - destination:
        host: baserow.book-stack.svc.cluster.local
        port:
          number: 80
  - match:
    - headers:
        host:
          exact: nocodb.yourdomain.com
    route:
    - destination:
        host: nocodb.book-stack.svc.cluster.local
        port:
          number: 8080
EOF

    # Gateway configuration
    cat > k8s/networking/service-mesh/gateway.yaml << 'EOF'
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: book-gateway
  namespace: book-stack
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*.yourdomain.com"
    tls:
      httpsRedirect: true
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: book-stack-tls
    hosts:
    - "*.yourdomain.com"
EOF

    print_success "Service mesh configuration created"
}

# Function to validate network setup
validate_network_setup() {
    print_status "Validating network setup..."
    
    local all_valid=true
    
    # Check namespaces
    for namespace in "${NAMESPACES[@]}"; do
        if kubectl get namespace "$namespace" &> /dev/null; then
            print_success "Namespace $namespace exists"
        else
            print_error "Namespace $namespace does not exist"
            all_valid=false
        fi
    done
    
    # Check network policies
    local policies=("default-deny-ingress" "database-access-policy" "application-access-policy" "monitoring-access-policy" "security-access-policy")
    
    for policy in "${policies[@]}"; do
        local found=false
        for namespace in "${NAMESPACES[@]}"; do
            if kubectl get networkpolicy "$policy" -n "$namespace" &> /dev/null; then
                found=true
                break
            fi
        done
        
        if $found; then
            print_success "Network policy $policy is applied"
        else
            print_warning "Network policy $policy not found in any namespace"
        fi
    done
    
    # Check ingress controller
    if kubectl get pods -n ingress-nginx | grep -q "ingress-nginx-controller"; then
        print_success "Ingress controller is running"
    else
        print_warning "Ingress controller not found"
    fi
    
    if $all_valid; then
        print_success "Network setup validation completed successfully"
        return 0
    else
        print_error "Some network components are missing or invalid"
        return 1
    fi
}

# Function to remove network setup
remove_network_setup() {
    print_status "Removing network setup..."
    
    # Remove network policies
    for namespace in "${NAMESPACES[@]}"; do
        kubectl delete networkpolicy --all -n "$namespace" 2>/dev/null || true
    done
    
    # Remove network policy files
    rm -rf k8s/networking/
    
    print_success "Network setup removed"
}

# Function to list network status
list_network_status() {
    print_status "Kubernetes Network Status:"
    echo ""
    
    # List namespaces
    echo "Namespaces:"
    for namespace in "${NAMESPACES[@]}"; do
        if kubectl get namespace "$namespace" &> /dev/null; then
            echo -e "  ${GREEN}✓${NC} $namespace"
        else
            echo -e "  ${RED}✗${NC} $namespace"
        fi
    done
    
    echo ""
    echo "Network Policies:"
    kubectl get networkpolicy --all-namespaces -o wide 2>/dev/null || echo "  No network policies found"
    
    echo ""
    echo "Services:"
    kubectl get services --all-namespaces -o wide 2>/dev/null || echo "  No services found"
}

# Function to show help
show_help() {
    echo "Kubernetes Network Setup Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  create     Create namespaces and network policies"
    echo "  apply      Apply network policies to cluster"
    echo "  mesh       Create service mesh configuration"
    echo "  validate   Validate network configuration"
    echo "  list       List network status"
    echo "  remove     Remove network setup"
    echo "  help       Show this help message"
    echo ""
    echo "Namespaces managed:"
    for namespace in "${NAMESPACES[@]}"; do
        echo "  - $namespace"
    done
}

# Main execution
main() {
    check_kubectl
    
    case "${1:-help}" in
        create)
            create_namespaces
            create_network_policies
            ;;
        apply)
            apply_network_policies
            ;;
        mesh)
            create_service_mesh_config
            ;;
        validate)
            validate_network_setup
            ;;
        list)
            list_network_status
            ;;
        remove)
            remove_network_setup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"