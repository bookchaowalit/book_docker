#!/bin/bash

# Docker Compose Multi-Service Manager
# This script manages multiple docker-compose services with shared networking

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SHARED_NETWORK="book-shared-network"
SHARED_NETWORKS="shared-networks"
SHARED_NET="shared-net"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$BASE_DIR/services.conf"

# Services configuration - organized by categories
declare -A SERVICES=(
    # Infrastructure services
    ["traefik"]="infrastructure/traefik"
    ["portainer"]="infrastructure/portainer"
    ["airflow"]="infrastructure/airflow"
    ["vault"]="infrastructure/vault"
    ["consul"]="infrastructure/consul"
    ["nginx"]="infrastructure/nginx"
    ["gitlab"]="infrastructure/gitlab"
    ["gitlab-runner"]="infrastructure/gitlab-runner"
    ["jenkins"]="infrastructure/jenkins"
    ["rabbitmq"]="infrastructure/rabbitmq"
    ["kafka"]="infrastructure/kafka"

    # Database services
    ["postgres"]="databases/postgres"
    ["mysql"]="databases/mysql"
    ["mariadb"]="databases/mariadb"
    ["redis"]="databases/redis"
    ["mongodb"]="databases/mongodb"
    ["influxdb"]="databases/influxdb"
    ["neo4j"]="databases/neo4j"
    ["couchdb"]="databases/couchdb"
    ["sqlite"]="databases/sqlite"
    ["cassandra"]="databases/cassandra"

    # Monitoring services
    ["elasticsearch"]="monitoring/elasticsearch-logstash-kibana"
    ["prometheus"]="monitoring/prometheus"
    ["grafana"]="monitoring/grafana"

    # Storage services
    ["minio"]="storage/minio"

    # Application services
    ["baserow"]="applications/baserow"
    ["nocodb"]="applications/nocodb"
    ["comfyui"]="applications/comfyui"
    ["open-webui"]="applications/open-web-ui"
    ["litellm"]="applications/litellm"
    ["n8n"]="applications/n8n"
    ["twenty"]="applications/twenty"
    ["wordpress"]="applications/wordpress"
    ["nca-toolkit"]="applications/nca_toolkit"
    ["openbb"]="applications/openbb"
    ["mixpost"]="applications/mixpost"
    ["nextcloud"]="applications/nextcloud"
    ["rocketchat"]="applications/rocketchat"
    ["metabase"]="applications/metabase"
    ["vscode-server"]="applications/vscode-server"
    ["vikunja"]="applications/vikunja"
    ["bookstack"]="applications/bookstack"
    ["ghost"]="applications/ghost"
    ["jupyterhub"]="applications/jupyterhub"
    ["plausible"]="applications/plausible"
    ["pocketbase"]="applications/pocketbase"
    ["metabase"]="applications/metabase"
    ["code-server"]="applications/code-server"
    ["vikunja"]="applications/vikunja"
    ["bookstack"]="applications/bookstack"
    ["ghost"]="applications/ghost"
    ["jupyterhub"]="applications/jupyterhub"
    ["plausible"]="applications/plausible"
    ["pocketbase"]="applications/pocketbase"

    # Utility services
    ["backup"]="utilities/backup"
    ["phpmyadmin"]="utilities/phpmyadmin"
    ["flaresolverr"]="utilities/flaresolverr"
)

# Service categories for organized deployment
declare -A CATEGORIES=(
    ["infrastructure"]="traefik portainer airflow vault consul nginx gitlab gitlab-runner jenkins rabbitmq kafka"
    ["databases"]="postgres mysql mariadb redis mongodb influxdb neo4j couchdb sqlite cassandra"
    ["monitoring"]="elasticsearch prometheus grafana"
    ["storage"]="minio"
    ["applications"]="baserow nocodb comfyui open-webui litellm n8n twenty wordpress nca-toolkit openbb mixpost nextcloud rocketchat metabase vscode-server vikunja bookstack ghost jupyterhub plausible pocketbase"
    ["utilities"]="backup phpmyadmin flaresolverr"
)

# Function to print usage
print_usage() {
    echo -e "${BLUE}Docker Compose Multi-Service Manager${NC}"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  up [service...]       - Start services (all if none specified)"
    echo "  down [service...]     - Stop services (all if none specified)"
    echo "  restart [service...]  - Restart services"
    echo "  status                - Show status of all services"
    echo "  logs [service]        - Show logs for service"
    echo "  ps                    - Show running containers"
    echo "  pull [service...]     - Pull latest images"
    echo "  build [service...]    - Build services"
    echo "  category [cat] [cmd]  - Manage service categories"
    echo "  list                  - List all available services"
    echo "  add [name] [path]     - Add new service to configuration"
    echo "  remove [name]         - Remove service from configuration"
    echo "  network               - Create/manage shared network"
    echo "  clean                 - Clean up unused containers/networks"
    echo "  help                  - Show this help message"
    echo ""
    echo "Categories: infrastructure, databases, monitoring, storage, applications, utilities"
    echo ""
    echo "Examples:"
    echo "  $0 up                    # Start all services"
    echo "  $0 up traefik postgres   # Start specific services"
    echo "  $0 category databases up # Start all database services"
    echo "  $0 down                  # Stop all services"
    echo "  $0 logs grafana          # View grafana logs"
}

# Function to check if docker-compose is available
check_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        echo -e "${RED}Neither docker-compose nor docker compose is available${NC}"
        exit 1
    fi
}

# Function to create shared network
create_shared_network() {
    # Create book-shared-network
    if ! docker network ls --format "{{.Name}}" | grep -q "^${SHARED_NETWORK}$"; then
        echo -e "${YELLOW}Creating shared network: $SHARED_NETWORK${NC}"
        docker network create "$SHARED_NETWORK" --driver bridge
        echo -e "${GREEN}✓ Shared network created${NC}"
    else
        echo -e "${GREEN}✓ Shared network already exists${NC}"
    fi

    # Create shared-networks
    if ! docker network ls --format "{{.Name}}" | grep -q "^${SHARED_NETWORKS}$"; then
        echo -e "${YELLOW}Creating shared network: $SHARED_NETWORKS${NC}"
        docker network create "$SHARED_NETWORKS" --driver bridge
        echo -e "${GREEN}✓ Shared network created${NC}"
    else
        echo -e "${GREEN}✓ Shared network already exists${NC}"
    fi

    # Create shared-net
    if ! docker network ls --format "{{.Name}}" | grep -q "^${SHARED_NET}$"; then
        echo -e "${YELLOW}Creating shared network: $SHARED_NET${NC}"
        docker network create "$SHARED_NET" --driver bridge
        echo -e "${GREEN}✓ Shared network created${NC}"
    else
        echo -e "${GREEN}✓ Shared network already exists${NC}"
    fi
}

# Function to load services from config file
load_services_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        while IFS='=' read -r key value; do
            [[ $key =~ ^[[:space:]]*# ]] && continue  # Skip comments
            [[ -z $key ]] && continue                 # Skip empty lines
            SERVICES["$key"]="$value"
        done < "$CONFIG_FILE"
    fi
}

# Function to save services to config file
save_services_config() {
    echo "# Docker Compose Services Configuration" > "$CONFIG_FILE"
    echo "# Format: service_name=directory_path" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"

    for service in "${!SERVICES[@]}"; do
        echo "$service=${SERVICES[$service]}" >> "$CONFIG_FILE"
    done

    echo -e "${GREEN}✓ Configuration saved to $CONFIG_FILE${NC}"
}

# Function to validate service exists
validate_service() {
    local service="$1"
    local service_dir="$BASE_DIR/${SERVICES[$service]}"

    if [[ -z "${SERVICES[$service]}" ]]; then
        echo -e "${RED}✗ Service '$service' not found${NC}"
        return 1
    fi

    if [[ ! -f "$service_dir/docker-compose.yml" ]]; then
        echo -e "${RED}✗ docker-compose.yml not found in $service_dir${NC}"
        return 1
    fi

    return 0
}

# Function to run docker-compose command for a service
run_compose_command() {
    local service="$1"
    local command="$2"
    local service_dir="$BASE_DIR/${SERVICES[$service]}"

    if ! validate_service "$service"; then
        return 1
    fi

    echo -e "${YELLOW}$command $service...${NC}"

    cd "$service_dir"

    # Set environment variables for shared networks
    export SHARED_NETWORK="$SHARED_NETWORK"
    export SHARED_NETWORKS="$SHARED_NETWORKS"
    export SHARED_NET="$SHARED_NET"

    case "$command" in
        "up")
            $COMPOSE_CMD up -d
            ;;
        "down")
            $COMPOSE_CMD down
            ;;
        "restart")
            $COMPOSE_CMD restart
            ;;
        "pull")
            $COMPOSE_CMD pull
            ;;
        "build")
            $COMPOSE_CMD build
            ;;
        "logs")
            $COMPOSE_CMD logs -f --tail=100
            ;;
        "ps")
            $COMPOSE_CMD ps
            ;;
        *)
            $COMPOSE_CMD "$command"
            ;;
    esac

    local exit_code=$?
    cd "$BASE_DIR"

    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓ $service $command completed${NC}"
    else
        echo -e "${RED}✗ $service $command failed (skipping)${NC}"
    fi

    return $exit_code
}

# Function to get services by category
get_services_by_category() {
    local category="$1"
    echo "${CATEGORIES[$category]}"
}

# Function to list all services
list_services() {
    echo -e "${BLUE}Available Services:${NC}"
    echo ""

    for category in "${!CATEGORIES[@]}"; do
        echo -e "${YELLOW}$category:${NC}"
        for service in ${CATEGORIES[$category]}; do
            local status="❌"
            local service_dir="$BASE_DIR/${SERVICES[$service]}"

            if [[ -f "$service_dir/docker-compose.yml" ]]; then
                status="✅"
            fi

            echo "  $status $service (${SERVICES[$service]})"
        done
        echo ""
    done
}

# Function to show service status
show_status() {
    echo -e "${BLUE}Service Status:${NC}"
    echo ""

    for service in "${!SERVICES[@]}"; do
        local service_dir="$BASE_DIR/${SERVICES[$service]}"

        if [[ -f "$service_dir/docker-compose.yml" ]]; then
            cd "$service_dir"
            local containers=$($COMPOSE_CMD ps -q 2>/dev/null | wc -l)
            local running=$($COMPOSE_CMD ps --filter "status=running" -q 2>/dev/null | wc -l)

            if [[ $containers -gt 0 ]]; then
                if [[ $running -eq $containers ]]; then
                    echo -e "  ${GREEN}✓${NC} $service ($running/$containers running)"
                else
                    echo -e "  ${YELLOW}⚠${NC} $service ($running/$containers running)"
                fi
            else
                echo -e "  ${RED}✗${NC} $service (stopped)"
            fi
            cd "$BASE_DIR"
        else
            echo -e "  ${RED}?${NC} $service (no docker-compose.yml)"
        fi
    done
}

# Function to add new service
add_service() {
    local name="$1"
    local path="$2"

    if [[ -z "$name" || -z "$path" ]]; then
        echo -e "${RED}Usage: $0 add [service_name] [directory_path]${NC}"
        return 1
    fi

    local service_dir="$BASE_DIR/$path"

    if [[ ! -f "$service_dir/docker-compose.yml" ]]; then
        echo -e "${RED}✗ docker-compose.yml not found in $service_dir${NC}"
        return 1
    fi

    SERVICES["$name"]="$path"
    save_services_config

    echo -e "${GREEN}✓ Service '$name' added${NC}"
}

# Function to remove service
remove_service() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo -e "${RED}Usage: $0 remove [service_name]${NC}"
        return 1
    fi

    if [[ -z "${SERVICES[$name]}" ]]; then
        echo -e "${RED}✗ Service '$name' not found${NC}"
        return 1
    fi

    unset SERVICES["$name"]
    save_services_config

    echo -e "${GREEN}✓ Service '$name' removed${NC}"
}

# Function to clean up unused resources
cleanup() {
    echo -e "${YELLOW}Cleaning up unused Docker resources...${NC}"

    docker container prune -f
    docker network prune -f
    docker volume prune -f
    docker image prune -f

    echo -e "${GREEN}✓ Cleanup completed${NC}"
}

# Main execution
main() {
    local command="${1:-help}"
    shift || true

    check_docker_compose
    load_services_config

    case "$command" in
        "up")
            create_shared_network
            if [[ $# -eq 0 ]]; then
                # Start all services in order
                for category in infrastructure databases monitoring storage applications utilities; do
                    for service in ${CATEGORIES[$category]}; do
                        run_compose_command "$service" "up" || true  # Continue on error
                    done
                done
            else
                for service in "$@"; do
                    run_compose_command "$service" "up" || true  # Continue on error
                done
            fi
            ;;
        "up-resilient")
            create_shared_network
            echo -e "${BLUE}🛡️  Starting services in resilient mode (skipping errors)...${NC}"
            local failed_services=()
            local successful_services=()

            if [[ $# -eq 0 ]]; then
                # Start all services in order
                for category in infrastructure databases monitoring storage applications utilities; do
                    echo -e "${YELLOW}📦 Starting $category services...${NC}"
                    for service in ${CATEGORIES[$category]}; do
                        if run_compose_command "$service" "up"; then
                            successful_services+=("$service")
                        else
                            failed_services+=("$service")
                        fi
                    done
                done
            else
                for service in "$@"; do
                    if run_compose_command "$service" "up"; then
                        successful_services+=("$service")
                    else
                        failed_services+=("$service")
                    fi
                done
            fi

            # Summary report
            echo ""
            echo -e "${GREEN}✅ Successfully started services:${NC}"
            for service in "${successful_services[@]}"; do
                echo -e "  ✓ $service"
            done

            if [[ ${#failed_services[@]} -gt 0 ]]; then
                echo ""
                echo -e "${RED}❌ Failed to start services:${NC}"
                for service in "${failed_services[@]}"; do
                    echo -e "  ✗ $service"
                done
                echo ""
                echo -e "${YELLOW}💡 Common issues:${NC}"
                echo -e "  • Port conflicts (check with: docker ps)"
                echo -e "  • Missing environment files"
                echo -e "  • Service dependencies not ready"
            fi
            ;;
        "down")
            if [[ $# -eq 0 ]]; then
                # Stop all services in reverse order
                for category in utilities applications storage monitoring databases infrastructure; do
                    for service in ${CATEGORIES[$category]}; do
                        run_compose_command "$service" "down"
                    done
                done
            else
                for service in "$@"; do
                    run_compose_command "$service" "down"
                done
            fi
            ;;
        "restart")
            for service in "$@"; do
                run_compose_command "$service" "restart"
            done
            ;;
        "logs")
            if [[ $# -eq 1 ]]; then
                run_compose_command "$1" "logs"
            else
                echo -e "${RED}Usage: $0 logs [service_name]${NC}"
            fi
            ;;
        "pull"|"build")
            if [[ $# -eq 0 ]]; then
                for service in "${!SERVICES[@]}"; do
                    run_compose_command "$service" "$command"
                done
            else
                for service in "$@"; do
                    run_compose_command "$service" "$command"
                done
            fi
            ;;
        "category")
            local category="$1"
            local cat_command="$2"
            shift 2 || true

            if [[ -z "$category" || -z "$cat_command" ]]; then
                echo -e "${RED}Usage: $0 category [category] [command]${NC}"
                return 1
            fi

            local services=$(get_services_by_category "$category")
            if [[ -z "$services" ]]; then
                echo -e "${RED}✗ Category '$category' not found${NC}"
                return 1
            fi

            echo -e "${BLUE}Running '$cat_command' for category '$category'${NC}"
            for service in $services; do
                run_compose_command "$service" "$cat_command"
            done
            ;;
        "status")
            show_status
            ;;
        "ps")
            for service in "${!SERVICES[@]}"; do
                echo -e "${YELLOW}=== $service ===${NC}"
                run_compose_command "$service" "ps"
                echo ""
            done
            ;;
        "list")
            list_services
            ;;
        "add")
            add_service "$@"
            ;;
        "remove")
            remove_service "$@"
            ;;
        "network")
            create_shared_network
            ;;
        "clean")
            cleanup
            ;;
        "help")
            print_usage
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            print_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
