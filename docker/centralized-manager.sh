#!/bin/bash

# Centralized Infrastructure Manager
# This script manages the centralized infrastructure setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to start centralized infrastructure
start_infrastructure() {
    echo -e "${BLUE}🚀 Starting centralized infrastructure...${NC}"
    
    # Create networks if they don't exist
    docker network create shared-networks 2>/dev/null || true
    
    # Start core infrastructure services
    echo -e "${YELLOW}Starting core services...${NC}"
    docker-compose -f docker-compose.centralized.yml up -d postgres mysql redis mongodb traefik
    
    # Wait for databases to be ready
    echo -e "${YELLOW}Waiting for databases to be ready...${NC}"
    sleep 30
    
    # Verify services are healthy
    echo -e "${YELLOW}Verifying service health...${NC}"
    docker-compose -f docker-compose.centralized.yml ps
    
    echo -e "${GREEN}✅ Centralized infrastructure started successfully!${NC}"
}

# Function to stop centralized infrastructure
stop_infrastructure() {
    echo -e "${BLUE}🛑 Stopping centralized infrastructure...${NC}"
    docker-compose -f docker-compose.centralized.yml down
    echo -e "${GREEN}✅ Centralized infrastructure stopped!${NC}"
}

# Function to show infrastructure status
show_status() {
    echo -e "${BLUE}📊 Centralized Infrastructure Status${NC}"
    echo "=================================="
    docker-compose -f docker-compose.centralized.yml ps
    
    echo -e "\n${YELLOW}🌐 Network Information:${NC}"
    docker network ls | grep shared-networks
    
    echo -e "\n${YELLOW}💾 Volume Information:${NC}"
    docker volume ls | grep shared_
}

# Function to show logs
show_logs() {
    local service=${1:-}
    if [[ -n "$service" ]]; then
        docker-compose -f docker-compose.centralized.yml logs -f "$service"
    else
        docker-compose -f docker-compose.centralized.yml logs -f
    fi
}

# Function to restart services
restart_services() {
    echo -e "${BLUE}🔄 Restarting centralized infrastructure...${NC}"
    docker-compose -f docker-compose.centralized.yml restart
    echo -e "${GREEN}✅ Services restarted!${NC}"
}

# Main function
main() {
    case "${1:-help}" in
        "start")
            start_infrastructure
            ;;
        "stop")
            stop_infrastructure
            ;;
        "restart")
            restart_services
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs "$2"
            ;;
        "help"|*)
            echo "Usage: $0 {start|stop|restart|status|logs [service]}"
            echo ""
            echo "Commands:"
            echo "  start    - Start centralized infrastructure"
            echo "  stop     - Stop centralized infrastructure"
            echo "  restart  - Restart all services"
            echo "  status   - Show service status"
            echo "  logs     - Show logs (optionally for specific service)"
            ;;
    esac
}

main "$@"
