#!/bin/bash

# Docker Services Manager - Complete Infrastructure Control
# This script allows you to manage all Docker services from the root directory

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_MANAGER="$SCRIPT_DIR/docker/docker-compose-manager.sh"

if [ ! -f "$DOCKER_MANAGER" ]; then
    echo -e "${RED}Error: docker-compose-manager.sh not found at $DOCKER_MANAGER${NC}"
    exit 1
fi

# Function to setup Docker networks (FIXED - only uses shared-networks)
setup_networks() {
    echo -e "${BLUE}🌐 Setting up Docker networks...${NC}"

    # Only create the one network that all services actually use
    local network_name="shared-networks"
    local subnet="172.20.0.0/16"

    if docker network ls --format "{{.Name}}" | grep -q "^${network_name}$"; then
        echo -e "${YELLOW}⚠️ Network $network_name already exists${NC}"

        # Validate existing network
        local existing_subnet=$(docker network inspect "$network_name" --format "{{range .IPAM.Config}}{{.Subnet}}{{end}}" 2>/dev/null)
        if [[ "$existing_subnet" == "$subnet" ]]; then
            echo -e "${GREEN}✅ Network $network_name is correctly configured ($existing_subnet)${NC}"
        else
            echo -e "${YELLOW}⚠️ Network $network_name exists but with different subnet: $existing_subnet${NC}"
        fi
    else
        echo -e "${BLUE}📡 Creating network: $network_name${NC}"
        if docker network create \
            --driver bridge \
            --subnet="$subnet" \
            --opt com.docker.network.bridge.enable_icc=true \
            --opt com.docker.network.bridge.enable_ip_masquerade=true \
            --opt com.docker.network.driver.mtu=1500 \
            --label description="Main shared network for inter-service communication" \
            --label managed-by="docker-manager" \
            "$network_name" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Created network: $network_name ($subnet)${NC}"
        else
            echo -e "${RED}❌ Failed to create network: $network_name${NC}"
            echo -e "${YELLOW}💡 This may be due to subnet conflicts. Try: docker network prune${NC}"
            return 1
        fi
    fi

    echo -e "${GREEN}✅ Network setup completed${NC}"
}

# Function to validate networks (FIXED - only checks shared-networks)
validate_networks() {
    echo -e "${BLUE}🔍 Validating network configuration...${NC}"

    local network="shared-networks"

    if docker network ls --format "{{.Name}}" | grep -q "^${network}$"; then
        local subnet=$(docker network inspect "$network" --format "{{range .IPAM.Config}}{{.Subnet}}{{end}}" 2>/dev/null)
        if [[ -n "$subnet" ]]; then
            echo -e "${GREEN}✅ Network $network is valid (subnet: $subnet)${NC}"
            return 0
        else
            echo -e "${RED}❌ Network $network has no subnet configured${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Network $network does not exist${NC}"
        return 1
    fi
}

# Function to list networks (FIXED - only shows relevant networks)
list_networks() {
    echo -e "${BLUE}📋 Docker Network Status${NC}"
    echo "=========================="

    # Show our main network
    local network="shared-networks"
    if docker network ls --format "{{.Name}}" | grep -q "^${network}$"; then
        echo -e "${GREEN}✓${NC} $network"
        docker network inspect "$network" --format "  Subnet: {{range .IPAM.Config}}{{.Subnet}}{{end}}" 2>/dev/null
        local container_count=$(docker network inspect "$network" --format "{{len .Containers}}" 2>/dev/null)
        echo -e "  Connected containers: $container_count"
    else
        echo -e "${RED}✗${NC} $network (not found)"
    fi

    echo ""
    echo -e "${BLUE}All Docker networks:${NC}"
    docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
}

# Function to check Docker connectivity
check_docker_connectivity() {
    echo -e "${BLUE}🔍 Checking Docker connectivity...${NC}"

    # Test basic Docker connectivity
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker daemon not accessible${NC}"
        return 1
    fi

    echo -e "${GREEN}✅ Docker connectivity is good${NC}"
    return 0
}

# Function to clean up conflicting networks
cleanup_conflicting_networks() {
    echo -e "${BLUE}🧹 Cleaning up conflicting networks...${NC}"

    # Remove any networks that might conflict with our subnet range
    local conflicting_networks=$(docker network ls --format "{{.Name}}" | grep -E "(monitoring|database|application|security)-network" || true)

    if [[ -n "$conflicting_networks" ]]; then
        echo -e "${YELLOW}Found potentially conflicting networks:${NC}"
        echo "$conflicting_networks"

        for network in $conflicting_networks; do
            # Check if network is in use
            local containers=$(docker network inspect "$network" --format "{{len .Containers}}" 2>/dev/null || echo "0")
            if [[ "$containers" == "0" ]]; then
                echo -e "${YELLOW}Removing unused network: $network${NC}"
                docker network rm "$network" 2>/dev/null || true
            else
                echo -e "${YELLOW}Keeping network $network (has $containers containers)${NC}"
            fi
        done
    else
        echo -e "${GREEN}✅ No conflicting networks found${NC}"
    fi
}

# Enhanced help function
show_help() {
    echo -e "${BLUE}🐳 Docker Services Manager${NC}"
    echo ""
    echo -e "${GREEN}Quick Commands:${NC}"
    echo "  ./docker-manager.sh start-all      # Start all services in proper order"
    echo "  ./docker-manager.sh start-safe     # Start all services, skip errors"
    echo "  ./docker-manager.sh start-proper   # Start with proper dependency order"
    echo "  ./docker-manager.sh stop-all       # Stop all services safely"
    echo "  ./docker-manager.sh restart-all    # Restart all services"
    echo "  ./docker-manager.sh demo           # Start essential services only"
    echo "  ./docker-manager.sh status         # Show status of all services"
    echo "  ./docker-manager.sh fix-ports      # Stop conflicting services"
    echo ""
    echo -e "${GREEN}Network Commands:${NC}"
    echo "  ./docker-manager.sh setup-networks # Create required Docker networks"
    echo "  ./docker-manager.sh list-networks  # Show network status"
    echo "  ./docker-manager.sh fix-networks   # Fix network conflicts"
    echo ""
    echo -e "${GREEN}Diagnostic Commands:${NC}"
    echo "  ./docker-manager.sh diagnose       # Run comprehensive diagnostics"
    echo "  ./docker-manager.sh fix-all        # Fix issues and start services"
    echo "  ./docker-manager.sh test [service] # Test specific service"
    echo ""
    echo -e "${GREEN}Service Categories:${NC}"
    echo "  infrastructure: traefik, portainer, vault, consul"
    echo "  databases:      postgres, mysql, mariadb, redis, mongodb"
    echo "  monitoring:     elasticsearch, prometheus, grafana"
    echo "  storage:        minio"
    echo "  applications:   baserow, nocodb, n8n, twenty, etc."
    echo ""
    echo -e "${GREEN}Advanced Usage:${NC}"
    echo "  ./docker-manager.sh up [service...]        # Start specific services"
    echo "  ./docker-manager.sh down [service...]      # Stop specific services"
    echo "  ./docker-manager.sh logs [service]         # View service logs"
    echo "  ./docker-manager.sh category databases up  # Start all database services"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  ./docker-manager.sh fix-networks            # Fix network conflicts first"
    echo "  ./docker-manager.sh start-proper            # Start with dependency handling"
    echo "  ./docker-manager.sh demo                    # Quick demo setup"
    echo "  ./docker-manager.sh up postgres grafana     # Start just postgres and grafana"
    echo "  ./docker-manager.sh category monitoring up  # Start monitoring stack"
    echo ""
}

# Function to run diagnostics
run_diagnostics() {
    echo -e "${BLUE}🔍 Running comprehensive diagnostics...${NC}"
    echo "======================================"

    # Check Docker connectivity
    if ! check_docker_connectivity; then
        echo -e "${RED}❌ Docker connectivity failed${NC}"
        return 1
    fi

    # Check networks
    echo -e "\n${YELLOW}Checking networks...${NC}"
    if validate_networks; then
        echo -e "${GREEN}✅ Networks are valid${NC}"
    else
        echo -e "${YELLOW}⚠️ Network issues detected - run: ./docker-manager.sh fix-networks${NC}"
    fi

    # Check for common port conflicts
    echo -e "\n${YELLOW}Checking for port conflicts...${NC}"
    local common_ports=("80" "443" "3306" "5432" "6379" "27017" "9200")
    local conflicts_found=false

    for port in "${common_ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port " && ! docker ps --format "{{.Ports}}" | grep -q ":$port->"; then
            echo -e "${RED}⚠️ Port $port is occupied by non-Docker process${NC}"
            conflicts_found=true
        fi
    done

    if ! $conflicts_found; then
        echo -e "${GREEN}✅ No port conflicts detected${NC}"
    fi

    # Check disk space
    echo -e "\n${YELLOW}Checking disk space...${NC}"
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 85 ]]; then
        echo -e "${RED}⚠️ Disk usage is high: ${disk_usage}%${NC}"
        echo -e "${YELLOW}💡 Consider running: ./docker-manager.sh cleanup${NC}"
    else
        echo -e "${GREEN}✅ Disk space is adequate: ${disk_usage}%${NC}"
    fi

    echo -e "\n${GREEN}✅ Diagnostics completed${NC}"
}

# Function to fix all issues
fix_all_issues() {
    echo -e "${BLUE}🔧 Fixing all detected issues...${NC}"
    echo "================================="

    # Fix networks first
    echo -e "${YELLOW}1. Fixing network issues...${NC}"
    cleanup_conflicting_networks
    setup_networks

    # Fix common Docker issues
    echo -e "${YELLOW}2. Fixing common Docker issues...${NC}"

    # Clean up stopped containers
    local stopped=$(docker ps -aq --filter "status=exited" | wc -l)
    if [[ $stopped -gt 0 ]]; then
        echo -e "${YELLOW}Removing $stopped stopped containers...${NC}"
        docker container prune -f >/dev/null 2>&1
    fi

    # Clean up dangling images
    local dangling=$(docker images -f "dangling=true" -q | wc -l)
    if [[ $dangling -gt 0 ]]; then
        echo -e "${YELLOW}Removing $dangling dangling images...${NC}"
        docker image prune -f >/dev/null 2>&1
    fi

    # Fix port conflicts by stopping conflicting services
    echo -e "${YELLOW}3. Stopping potentially conflicting services...${NC}"
    docker stop $(docker ps -q --filter "expose=5432" --filter "expose=3306" --filter "expose=80" --filter "expose=443") 2>/dev/null || true

    echo -e "${GREEN}✅ All issues fixed - ready to start services${NC}"

    # Now start services
    echo -e "\n${BLUE}🚀 Starting services with proper dependency handling...${NC}"
    exec "$DOCKER_MANAGER" up-resilient
}

# Function to test specific service
test_service() {
    local service=$1
    if [[ -z "$service" ]]; then
        echo -e "${RED}Please specify a service to test${NC}"
        echo "Usage: ./docker-manager.sh test <service-name>"
        return 1
    fi

    echo -e "${BLUE}🧪 Testing service: $service${NC}"
    echo "=========================="

    # Test the service startup
    if "$DOCKER_MANAGER" up "$service"; then
        echo -e "${GREEN}✅ Service $service started successfully${NC}"

        # Wait a moment and check if it's still running
        sleep 5
        if "$DOCKER_MANAGER" status | grep -q "$service.*running"; then
            echo -e "${GREEN}✅ Service $service is stable and running${NC}"
        else
            echo -e "${YELLOW}⚠️ Service $service started but may have issues${NC}"
            "$DOCKER_MANAGER" logs "$service"
        fi
    else
        echo -e "${RED}❌ Service $service failed to start${NC}"
        "$DOCKER_MANAGER" logs "$service"
        return 1
    fi
}

# Function to start services with proper dependency handling
start_proper() {
    echo -e "${BLUE}🚀 Starting services with proper dependency handling...${NC}"
    echo "=================================================="

    # First fix any issues
    cleanup_conflicting_networks
    setup_networks

    # Start with resilient mode
    exec "$DOCKER_MANAGER" up-resilient
}

# Check if no arguments provided
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

# Handle special commands
case "$1" in
    "start-all")
        echo -e "${GREEN}🚀 Starting all Docker services...${NC}"
        exec "$DOCKER_MANAGER" up
        ;;
    "start-safe")
        echo -e "${GREEN}🛡️  Starting all Docker services (resilient mode)...${NC}"
        exec "$DOCKER_MANAGER" up-resilient
        ;;
    "start-proper")
        start_proper
        ;;
    "stop-all")
        echo -e "${YELLOW}⏹️  Stopping all Docker services...${NC}"
        exec "$DOCKER_MANAGER" down
        ;;
    "restart-all")
        echo -e "${BLUE}🔄 Restarting all Docker services...${NC}"
        "$DOCKER_MANAGER" down
        sleep 2
        start_proper
        ;;
    "restart-proper")
        echo -e "${BLUE}🔄 Restarting with proper dependency handling...${NC}"
        "$DOCKER_MANAGER" down
        sleep 2
        start_proper
        ;;
    "demo")
        echo -e "${BLUE}🎯 Starting essential services for demo...${NC}"
        echo -e "${YELLOW}Starting: traefik, postgres, grafana, baserow, n8n${NC}"
        setup_networks
        exec "$DOCKER_MANAGER" up traefik postgres grafana baserow n8n
        ;;
    "fix-ports")
        echo -e "${YELLOW}🔧 Stopping services that might conflict with ports...${NC}"
        # Stop common conflicting containers
        docker stop $(docker ps -q --filter "expose=5432" --filter "expose=3306" --filter "expose=80" --filter "expose=443") 2>/dev/null || true
        echo -e "${GREEN}✅ Port conflicts resolved${NC}"
        ;;
    "setup-networks")
        setup_networks
        ;;
    "list-networks")
        list_networks
        ;;
    "fix-networks")
        echo -e "${BLUE}🔧 Fixing network conflicts...${NC}"
        cleanup_conflicting_networks
        setup_networks
        ;;
    "diagnose")
        run_diagnostics
        ;;
    "fix-all")
        fix_all_issues
        ;;
    "test")
        test_service "$2"
        ;;
    "cleanup")
        echo -e "${BLUE}🧹 Cleaning up Docker resources...${NC}"
        docker container prune -f
        docker image prune -f
        docker network prune -f
        docker volume prune -f
        echo -e "${GREEN}✅ Cleanup completed${NC}"
        ;;
    "help"|"-h"|"--help")
        show_help
        exit 0
        ;;
    *)
        # Pass all arguments to the docker-compose-manager script
        exec "$DOCKER_MANAGER" "$@"
        ;;
esac
