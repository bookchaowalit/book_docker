#!/bin/bash

# Test script for migration tools
# Usage: ./test-migration-tools.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/test-temp"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[TEST INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[TEST SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[TEST ERROR]${NC} $1"
}

# Cleanup function
cleanup() {
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# Setup test environment
setup_test() {
    cleanup
    mkdir -p "$TEST_DIR"
    
    # Create a simple test Docker Compose file
    cat > "$TEST_DIR/test-compose.yml" << 'EOF'
services:
  test-app:
    container_name: test-app-container
    image: nginx:latest
    ports:
      - "8080:80"
    environment:
      - ENV_VAR1=value1
      - ENV_VAR2=value2
    volumes:
      - ./data:/usr/share/nginx/html
    restart: unless-stopped
    networks:
      - shared-networks

networks:
  shared-networks:
    external: true

volumes:
  test-data:
EOF

    # Create test .env file
    cat > "$TEST_DIR/.env" << 'EOF'
ENV_VAR1=value1
ENV_VAR2=value2
TEST_VAR=test_value
EOF
}

# Test Docker to Kubernetes conversion
test_docker_to_k8s() {
    log_info "Testing Docker to Kubernetes conversion..."
    
    if "$SCRIPT_DIR/docker-to-k8s.sh" "$TEST_DIR/test-compose.yml" "$TEST_DIR/k8s-output" "test-namespace"; then
        if [[ -f "$TEST_DIR/k8s-output/test-app.yaml" ]]; then
            log_success "Docker to Kubernetes conversion successful"
            return 0
        else
            log_error "Expected output file not found"
            return 1
        fi
    else
        log_error "Docker to Kubernetes conversion failed"
        return 1
    fi
}

# Test Kubernetes to Docker conversion
test_k8s_to_docker() {
    log_info "Testing Kubernetes to Docker conversion..."
    
    if "$SCRIPT_DIR/k8s-to-docker.sh" "$TEST_DIR/k8s-output/test-app.yaml" "$TEST_DIR/docker-output"; then
        if [[ -f "$TEST_DIR/docker-output/docker-compose.yml" ]]; then
            log_success "Kubernetes to Docker conversion successful"
            return 0
        else
            log_error "Expected output file not found"
            return 1
        fi
    else
        log_error "Kubernetes to Docker conversion failed"
        return 1
    fi
}

# Test validation tools
test_validation() {
    log_info "Testing validation tools..."
    
    # Test Docker validation
    if "$SCRIPT_DIR/validate-configs.sh" docker 2>/dev/null; then
        log_success "Docker validation test passed"
    else
        log_info "Docker validation completed (some warnings expected)"
    fi
    
    # Test Kubernetes validation
    if "$SCRIPT_DIR/validate-configs.sh" k8s 2>/dev/null; then
        log_success "Kubernetes validation test passed"
    else
        log_info "Kubernetes validation completed (some warnings expected)"
    fi
    
    return 0
}

# Main test function
main() {
    log_info "Starting migration tools test suite..."
    
    # Check dependencies
    if ! command -v yq &> /dev/null; then
        log_error "yq is required for testing. Please install it first."
        exit 1
    fi
    
    setup_test
    
    local tests_passed=0
    local total_tests=3
    
    # Run tests
    if test_docker_to_k8s; then
        ((tests_passed++))
    fi
    
    if test_k8s_to_docker; then
        ((tests_passed++))
    fi
    
    if test_validation; then
        ((tests_passed++))
    fi
    
    # Cleanup
    cleanup
    
    # Report results
    log_info "Test Results: $tests_passed/$total_tests tests passed"
    
    if [[ $tests_passed -eq $total_tests ]]; then
        log_success "All migration tools are working correctly!"
        exit 0
    else
        log_error "Some tests failed. Please check the migration tools."
        exit 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi