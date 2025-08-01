#!/bin/bash

# Docker Issues Diagnosis and Resolution Script
# Usage: ./diagnose-docker-issues.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Check Docker daemon status
check_docker_daemon() {
    log_info "Checking Docker daemon status..."
    
    if ! docker info &>/dev/null; then
        log_error "Docker daemon is not running or accessible"
        log_info "Try: sudo systemctl start docker"
        return 1
    fi
    
    log_success "Docker daemon is running"
    return 0
}

# Check Docker network connectivity
check_network_connectivity() {
    log_info "Checking network connectivity..."
    
    # Test basic internet connectivity
    if ! ping -c 3 8.8.8.8 &>/dev/null; then
        log_error "No internet connectivity detected"
        return 1
    fi
    
    # Test Docker Hub connectivity
    if ! curl -s --connect-timeout 10 https://registry-1.docker.io/v2/ &>/dev/null; then
        log_warning "Docker Hub connectivity issues detected"
        log_info "This might cause image pull failures"
    else
        log_success "Docker Hub is accessible"
    fi
    
    return 0
}

# Check Docker storage space
check_docker_storage() {
    log_info "Checking Docker storage space..."
    
    local docker_root=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo "/var/lib/docker")
    local available_space=$(df -h "$docker_root" | awk 'NR==2 {print $4}')
    local used_percent=$(df -h "$docker_root" | awk 'NR==2 {print $5}' | sed 's/%//')
    
    log_info "Docker root directory: $docker_root"
    log_info "Available space: $available_space"
    log_info "Used: $used_percent%"
    
    if [[ $used_percent -gt 90 ]]; then
        log_error "Docker storage is critically low (${used_percent}% used)"
        log_info "Consider running: docker system prune -a"
        return 1
    elif [[ $used_percent -gt 80 ]]; then
        log_warning "Docker storage is getting low (${used_percent}% used)"
    else
        log_success "Docker storage space is adequate"
    fi
    
    return 0
}

# Clean up Docker resources
cleanup_docker_resources() {
    log_info "Cleaning up Docker resources..."
    
    # Remove stopped containers
    local stopped_containers=$(docker ps -aq --filter "status=exited" 2>/dev/null || echo "")
    if [[ -n "$stopped_containers" ]]; then
        log_info "Removing stopped containers..."
        docker rm $stopped_containers
    fi
    
    # Remove dangling images
    local dangling_images=$(docker images -qf "dangling=true" 2>/dev/null || echo "")
    if [[ -n "$dangling_images" ]]; then
        log_info "Removing dangling images..."
        docker rmi $dangling_images
    fi
    
    # Remove unused networks
    log_info "Removing unused networks..."
    docker network prune -f
    
    # Remove unused volumes
    log_info "Removing unused volumes..."
    docker volume prune -f
    
    log_success "Docker cleanup completed"
}

# Fix Docker daemon configuration
fix_docker_daemon() {
    log_info "Checking Docker daemon configuration..."
    
    local daemon_config="/etc/docker/daemon.json"
    
    if [[ ! -f "$daemon_config" ]]; then
        log_info "Creating Docker daemon configuration..."
        sudo mkdir -p /etc/docker
        sudo tee "$daemon_config" > /dev/null << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "registry-mirrors": [],
    "insecure-registries": [],
    "max-concurrent-downloads": 3,
    "max-concurrent-uploads": 5
}
EOF
        log_info "Restarting Docker daemon..."
        sudo systemctl restart docker
        sleep 5
    fi
    
    log_success "Docker daemon configuration checked"
}

# Pre-pull required images with retry logic
pre_pull_images() {
    log_info "Pre-pulling required images with retry logic..."
    
    local images=(
        "postgres:15-alpine"
        "mysql:8.0"
        "redis:7-alpine"
        "mongo:7"
        "traefik:v3.0"
    )
    
    for image in "${images[@]}"; do
        log_info "Pulling image: $image"
        
        local retry_count=0
        local max_retries=3
        
        while [[ $retry_count -lt $max_retries ]]; do
            if docker pull "$image"; then
                log_success "Successfully pulled: $image"
                break
            else
                ((retry_count++))
                log_warning "Failed to pull $image (attempt $retry_count/$max_retries)"
                
                if [[ $retry_count -lt $max_retries ]]; then
                    log_info "Retrying in 10 seconds..."
                    sleep 10
                else
                    log_error "Failed to pull $image after $max_retries attempts"
                    return 1
                fi
            fi
        done
    done
    
    log_success "All images pulled successfully"
}

# Restart Docker services with proper order
restart_docker_services() {
    log_info "Restarting Docker services in proper order..."
    
    # Stop all running containers gracefully
    local running_containers=$(docker ps -q 2>/dev/null || echo "")
    if [[ -n "$running_containers" ]]; then
        log_info "Stopping running containers..."
        docker stop $running_containers
    fi
    
    # Restart Docker daemon
    log_info "Restarting Docker daemon..."
    sudo systemctl restart docker
    sleep 10
    
    # Verify Docker is running
    if ! docker info &>/dev/null; then
        log_error "Docker failed to restart properly"
        return 1
    fi
    
    log_success "Docker services restarted successfully"
}

# Check for common Docker issues
check_common_issues() {
    log_info "Checking for common Docker issues..."
    
    # Check for permission issues
    if ! docker ps &>/dev/null; then
        log_warning "Docker permission issues detected"
        log_info "Consider adding your user to the docker group:"
        log_info "sudo usermod -aG docker \$USER"
        log_info "Then log out and log back in"
    fi
    
    # Check for conflicting processes
    local conflicting_processes=$(ps aux | grep -E "(dockerd|containerd)" | grep -v grep || echo "")
    if [[ -n "$conflicting_processes" ]]; then
        log_info "Docker processes running:"
        echo "$conflicting_processes"
    fi
    
    # Check system resources
    local memory_usage=$(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
    local cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    
    log_info "System memory usage: $memory_usage"
    log_info "System load average: $cpu_load"
    
    # Check if system is under heavy load
    local cpu_cores=$(nproc)
    if (( $(echo "$cpu_load > $cpu_cores" | bc -l) )); then
        log_warning "System is under heavy load (load: $cpu_load, cores: $cpu_cores)"
    fi
}

# Main diagnosis and fix function
main() {
    log_info "Starting Docker issues diagnosis..."
    
    local issues_found=0
    
    # Run all checks
    check_docker_daemon || ((issues_found++))
    check_network_connectivity || ((issues_found++))
    check_docker_storage || ((issues_found++))
    check_common_issues
    
    if [[ $issues_found -gt 0 ]]; then
        log_warning "Found $issues_found issues. Attempting to fix..."
        
        # Attempt fixes
        cleanup_docker_resources
        fix_docker_daemon
        restart_docker_services
        
        # Pre-pull images to avoid network issues during compose up
        if pre_pull_images; then
            log_success "All fixes applied successfully"
            log_info "You can now try running your Docker Compose commands again"
        else
            log_error "Some issues could not be resolved automatically"
            log_info "Manual intervention may be required"
            return 1
        fi
    else
        log_success "No critical issues found"
        log_info "If you're still experiencing problems, try pre-pulling images:"
        pre_pull_images
    fi
}

# Show usage information
usage() {
    cat << EOF
Docker Issues Diagnosis and Resolution Script

Usage: $0 [command]

Commands:
  check       - Run diagnosis checks only
  fix         - Run diagnosis and attempt fixes
  cleanup     - Clean up Docker resources
  pull        - Pre-pull required images
  restart     - Restart Docker services
  help        - Show this help message

Examples:
  $0 check     # Just check for issues
  $0 fix       # Check and fix issues
  $0 cleanup   # Clean up Docker resources
  $0 pull      # Pre-pull images

EOF
}

# Handle command line arguments
case "${1:-fix}" in
    "check")
        check_docker_daemon
        check_network_connectivity
        check_docker_storage
        check_common_issues
        ;;
    "fix")
        main
        ;;
    "cleanup")
        cleanup_docker_resources
        ;;
    "pull")
        pre_pull_images
        ;;
    "restart")
        restart_docker_services
        ;;
    "help"|*)
        usage
        ;;
esac