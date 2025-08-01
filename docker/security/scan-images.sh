#!/bin/bash

# Docker Image Security Scanning Script

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
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

# Function to scan image with Trivy (if available)
scan_with_trivy() {
    local image=$1
    
    if command -v trivy &> /dev/null; then
        print_status "Scanning $image with Trivy..."
        trivy image --severity HIGH,CRITICAL "$image"
    else
        print_warning "Trivy not installed. Install with: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin"
    fi
}

# Function to check image for security best practices
check_image_security() {
    local image=$1
    
    print_status "Checking security configuration for $image..."
    
    # Check if image runs as root
    local user=$(docker inspect "$image" --format '{{.Config.User}}' 2>/dev/null || echo "")
    if [[ -z "$user" || "$user" == "root" || "$user" == "0" ]]; then
        print_warning "Image $image runs as root user"
    else
        print_success "Image $image runs as non-root user: $user"
    fi
    
    # Check for exposed ports
    local ports=$(docker inspect "$image" --format '{{range $p, $conf := .Config.ExposedPorts}}{{$p}} {{end}}' 2>/dev/null || echo "")
    if [[ -n "$ports" ]]; then
        print_status "Exposed ports: $ports"
    fi
    
    # Check image size
    local size=$(docker images "$image" --format "{{.Size}}" 2>/dev/null || echo "unknown")
    print_status "Image size: $size"
}

# Function to scan all local images
scan_all_images() {
    print_status "Scanning all local Docker images..."
    
    local images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>")
    
    for image in $images; do
        echo ""
        print_status "=== Scanning $image ==="
        check_image_security "$image"
        scan_with_trivy "$image"
    done
}

# Function to scan specific image
scan_image() {
    local image=$1
    
    if [[ -z "$image" ]]; then
        print_error "Please provide an image name"
        exit 1
    fi
    
    print_status "Scanning specific image: $image"
    check_image_security "$image"
    scan_with_trivy "$image"
}

# Main execution
case "${1:-all}" in
    all)
        scan_all_images
        ;;
    image)
        scan_image "${2:-}"
        ;;
    *)
        echo "Usage: $0 [all|image <image-name>]"
        exit 1
        ;;
esac
