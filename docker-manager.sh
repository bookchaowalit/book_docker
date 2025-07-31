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

# Enhanced help function
show_help() {
    echo -e "${BLUE}🐳 Docker Services Manager${NC}"
    echo ""
    echo -e "${GREEN}Quick Commands:${NC}"
    echo "  ./docker-manager.sh start-all      # Start all services in proper order"
    echo "  ./docker-manager.sh start-safe     # Start all services, skip errors"
    echo "  ./docker-manager.sh stop-all       # Stop all services safely"
    echo "  ./docker-manager.sh restart-all    # Restart all services"
    echo "  ./docker-manager.sh demo           # Start essential services only"
    echo "  ./docker-manager.sh status         # Show status of all services"
    echo "  ./docker-manager.sh fix-ports      # Stop conflicting services"
    echo ""
    echo -e "${GREEN}Service Categories:${NC}"
    echo "  infrastructure: traefik, portainer"
    echo "  databases:      postgres, mysql, mariadb"
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
    echo "  ./docker-manager.sh start-safe              # Start everything, skip errors"
    echo "  ./docker-manager.sh demo                    # Quick demo setup"
    echo "  ./docker-manager.sh up postgres grafana     # Start just postgres and grafana"
    echo "  ./docker-manager.sh category monitoring up  # Start monitoring stack"
    echo ""
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
    "stop-all")
        echo -e "${YELLOW}⏹️  Stopping all Docker services...${NC}"
        exec "$DOCKER_MANAGER" down
        ;;
    "restart-all")
        echo -e "${BLUE}🔄 Restarting all Docker services...${NC}"
        "$DOCKER_MANAGER" down
        sleep 2
        exec "$DOCKER_MANAGER" up-resilient
        ;;
    "demo")
        echo -e "${BLUE}🎯 Starting essential services for demo...${NC}"
        echo -e "${YELLOW}Starting: traefik, postgres, grafana, baserow, n8n${NC}"
        exec "$DOCKER_MANAGER" up traefik postgres grafana baserow n8n
        ;;
    "fix-ports")
        echo -e "${YELLOW}🔧 Stopping services that might conflict with ports...${NC}"
        # Stop common conflicting containers
        docker stop $(docker ps -q --filter "expose=5432" --filter "expose=3306" --filter "expose=80" --filter "expose=443") 2>/dev/null || true
        echo -e "${GREEN}✅ Port conflicts resolved${NC}"
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
