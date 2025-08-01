#!/bin/bash

# Centralized Infrastructure Setup Script
# This script configures all applications to use shared infrastructure services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}🏗️ Centralizing Infrastructure Configuration${NC}"
echo "=================================================="

# Function to create centralized database configuration
create_centralized_db_config() {
    echo -e "\n${YELLOW}📊 Creating centralized database configuration...${NC}"
    
    # Create shared database environment file
    cat > "$BASE_DIR/docker/.env.shared" << 'EOF'
# Shared Infrastructure Configuration
# This file contains centralized database and service configurations

# PostgreSQL Configuration (Shared)
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres123
POSTGRES_DB=shared_db

# MySQL Configuration (Shared)
MYSQL_HOST=mysql
MYSQL_PORT=3306
MYSQL_ROOT_PASSWORD=mysql123
MYSQL_DATABASE=shared_db
MYSQL_USER=app_user
MYSQL_PASSWORD=app_password

# Redis Configuration (Shared)
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=redis123

# MongoDB Configuration (Shared)
MONGODB_HOST=mongodb
MONGODB_PORT=27017
MONGODB_USERNAME=admin
MONGODB_PASSWORD=admin123
MONGODB_DATABASE=shared_db

# Traefik Configuration
TRAEFIK_DOMAIN=localhost
TRAEFIK_API_DASHBOARD=true

# Shared Networks
SHARED_NETWORK=shared-networks
EOF

    echo -e "  ${GREEN}✓${NC} Created shared environment configuration"
}

# Function to update application configurations
update_application_configs() {
    echo -e "\n${YELLOW}🔧 Updating application configurations...${NC}"
    
    # Applications that should use PostgreSQL
    local postgres_apps=("baserow" "nocodb" "n8n" "twenty" "vikunja" "metabase" "nextcloud" "jupyterhub" "plausible")
    
    for app in "${postgres_apps[@]}"; do
        local app_dir="$BASE_DIR/docker/applications/$app"
        if [[ -d "$app_dir" ]]; then
            echo -e "  ${BLUE}Configuring $app for shared PostgreSQL...${NC}"
            
            # Update .env file to use shared database
            if [[ -f "$app_dir/.env" ]]; then
                # Backup original
                cp "$app_dir/.env" "$app_dir/.env.backup"
                
                # Update database configuration
                sed -i 's/^POSTGRES_HOST=.*/POSTGRES_HOST=postgres/' "$app_dir/.env" 2>/dev/null || true
                sed -i 's/^DB_HOST=.*/DB_HOST=postgres/' "$app_dir/.env" 2>/dev/null || true
                sed -i 's/^DATABASE_HOST=.*/DATABASE_HOST=postgres/' "$app_dir/.env" 2>/dev/null || true
                
                # Add shared database config if not exists
                if ! grep -q "POSTGRES_HOST=postgres" "$app_dir/.env"; then
                    echo "" >> "$app_dir/.env"
                    echo "# Shared Database Configuration" >> "$app_dir/.env"
                    echo "POSTGRES_HOST=postgres" >> "$app_dir/.env"
                    echo "POSTGRES_PORT=5432" >> "$app_dir/.env"
                    echo "POSTGRES_USER=postgres" >> "$app_dir/.env"
                    echo "POSTGRES_PASSWORD=postgres123" >> "$app_dir/.env"
                fi
                
                echo -e "    ${GREEN}✓${NC} Updated $app configuration"
            else
                echo -e "    ${YELLOW}⚠${NC} No .env file found for $app"
            fi
        fi
    done
    
    # Applications that should use MySQL
    local mysql_apps=("wordpress" "ghost" "bookstack" "mixpost")
    
    for app in "${mysql_apps[@]}"; do
        local app_dir="$BASE_DIR/docker/applications/$app"
        if [[ -d "$app_dir" ]]; then
            echo -e "  ${BLUE}Configuring $app for shared MySQL...${NC}"
            
            if [[ -f "$app_dir/.env" ]]; then
                cp "$app_dir/.env" "$app_dir/.env.backup"
                
                sed -i 's/^MYSQL_HOST=.*/MYSQL_HOST=mysql/' "$app_dir/.env" 2>/dev/null || true
                sed -i 's/^DB_HOST=.*/DB_HOST=mysql/' "$app_dir/.env" 2>/dev/null || true
                sed -i 's/^DATABASE_HOST=.*/DATABASE_HOST=mysql/' "$app_dir/.env" 2>/dev/null || true
                
                if ! grep -q "MYSQL_HOST=mysql" "$app_dir/.env"; then
                    echo "" >> "$app_dir/.env"
                    echo "# Shared Database Configuration" >> "$app_dir/.env"
                    echo "MYSQL_HOST=mysql" >> "$app_dir/.env"
                    echo "MYSQL_PORT=3306" >> "$app_dir/.env"
                    echo "MYSQL_ROOT_PASSWORD=mysql123" >> "$app_dir/.env"
                fi
                
                echo -e "    ${GREEN}✓${NC} Updated $app configuration"
            fi
        fi
    done
}

# Function to create centralized docker-compose override
create_centralized_override() {
    echo -e "\n${YELLOW}🐳 Creating centralized Docker Compose override...${NC}"
    
    cat > "$BASE_DIR/docker/docker-compose.centralized.yml" << 'EOF'
version: '3.8'

# Centralized Infrastructure Override
# This file ensures all services use shared infrastructure

networks:
  shared-networks:
    external: true

services:
  # Shared PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: shared_postgres
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres123
      POSTGRES_DB: shared_db
      POSTGRES_MULTIPLE_DATABASES: baserow,nocodb,n8n,twenty,vikunja,metabase,nextcloud,jupyterhub,plausible
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init-multiple-databases.sh:/docker-entrypoint-initdb.d/init-multiple-databases.sh:ro
    networks:
      - shared-networks
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
      timeout: 10s
      retries: 3
    labels:
      - "traefik.enable=false"

  # Shared MySQL Database
  mysql:
    image: mysql:8.0
    container_name: shared_mysql
    environment:
      MYSQL_ROOT_PASSWORD: mysql123
      MYSQL_DATABASE: shared_db
      MYSQL_USER: app_user
      MYSQL_PASSWORD: app_password
    volumes:
      - mysql_data:/var/lib/mysql
      - ./scripts/init-mysql-databases.sql:/docker-entrypoint-initdb.d/init-databases.sql:ro
    networks:
      - shared-networks
    ports:
      - "3306:3306"
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
    labels:
      - "traefik.enable=false"

  # Shared Redis
  redis:
    image: redis:7-alpine
    container_name: shared_redis
    command: redis-server --requirepass redis123
    volumes:
      - redis_data:/data
    networks:
      - shared-networks
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3
    labels:
      - "traefik.enable=false"

  # Shared MongoDB
  mongodb:
    image: mongo:6
    container_name: shared_mongodb
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: admin123
      MONGO_INITDB_DATABASE: shared_db
    volumes:
      - mongodb_data:/data/db
    networks:
      - shared-networks
    ports:
      - "27017:27017"
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 30s
      timeout: 10s
      retries: 3
    labels:
      - "traefik.enable=false"

  # Centralized Traefik
  traefik:
    image: traefik:v3.0
    container_name: shared_traefik
    command:
      - "--api.dashboard=true"
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=shared-networks"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--log.level=INFO"
    ports:
      - "80:80"
      - "443:443"
      - "8090:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik_data:/data
    networks:
      - shared-networks
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(`traefik.localhost`)"
      - "traefik.http.routers.traefik.service=api@internal"

volumes:
  postgres_data:
    name: shared_postgres_data
  mysql_data:
    name: shared_mysql_data
  redis_data:
    name: shared_redis_data
  mongodb_data:
    name: shared_mongodb_data
  traefik_data:
    name: shared_traefik_data
EOF

    echo -e "  ${GREEN}✓${NC} Created centralized Docker Compose configuration"
}

# Function to create database initialization scripts
create_db_init_scripts() {
    echo -e "\n${YELLOW}🗄️ Creating database initialization scripts...${NC}"
    
    # PostgreSQL multiple database initialization
    cat > "$BASE_DIR/docker/scripts/init-multiple-databases.sh" << 'EOF'
#!/bin/bash
set -e

function create_user_and_database() {
    local database=$1
    echo "Creating user and database '$database'"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        CREATE DATABASE $database;
        GRANT ALL PRIVILEGES ON DATABASE $database TO $POSTGRES_USER;
EOSQL
}

if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
    echo "Multiple database creation requested: $POSTGRES_MULTIPLE_DATABASES"
    for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
        create_user_and_database $db
    done
    echo "Multiple databases created"
fi
EOF

    # MySQL multiple database initialization
    cat > "$BASE_DIR/docker/scripts/init-mysql-databases.sql" << 'EOF'
-- Create databases for different applications
CREATE DATABASE IF NOT EXISTS wordpress;
CREATE DATABASE IF NOT EXISTS ghost;
CREATE DATABASE IF NOT EXISTS bookstack;
CREATE DATABASE IF NOT EXISTS mixpost;

-- Create application-specific users
CREATE USER IF NOT EXISTS 'wordpress'@'%' IDENTIFIED BY 'wordpress123';
CREATE USER IF NOT EXISTS 'ghost'@'%' IDENTIFIED BY 'ghost123';
CREATE USER IF NOT EXISTS 'bookstack'@'%' IDENTIFIED BY 'bookstack123';
CREATE USER IF NOT EXISTS 'mixpost'@'%' IDENTIFIED BY 'mixpost123';

-- Grant permissions
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'%';
GRANT ALL PRIVILEGES ON ghost.* TO 'ghost'@'%';
GRANT ALL PRIVILEGES ON bookstack.* TO 'bookstack'@'%';
GRANT ALL PRIVILEGES ON mixpost.* TO 'mixpost'@'%';

FLUSH PRIVILEGES;
EOF

    # Make scripts executable
    chmod +x "$BASE_DIR/docker/scripts/init-multiple-databases.sh"
    
    echo -e "  ${GREEN}✓${NC} Created database initialization scripts"
}

# Function to create centralized management script
create_centralized_manager() {
    echo -e "\n${YELLOW}🎛️ Creating centralized management script...${NC}"
    
    cat > "$BASE_DIR/docker/centralized-manager.sh" << 'EOF'
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
EOF

    chmod +x "$BASE_DIR/docker/centralized-manager.sh"
    echo -e "  ${GREEN}✓${NC} Created centralized management script"
}

# Function to update existing docker-compose files
update_existing_compose_files() {
    echo -e "\n${YELLOW}📝 Updating existing Docker Compose files...${NC}"
    
    # Find all docker-compose.yml files and update them to use external networks
    find "$BASE_DIR/docker" -name "docker-compose.yml" -type f | while read -r compose_file; do
        local dir=$(dirname "$compose_file")
        local service_name=$(basename "$dir")
        
        echo -e "  ${BLUE}Updating $service_name...${NC}"
        
        # Create backup
        cp "$compose_file" "$compose_file.backup"
        
        # Add external networks if not present
        if ! grep -q "external: true" "$compose_file"; then
            cat >> "$compose_file" << 'EOF'

# Added by centralization script
networks:
  shared-networks:
    external: true
EOF
        fi
        
        echo -e "    ${GREEN}✓${NC} Updated $service_name"
    done
}

# Main execution
main() {
    echo -e "${BLUE}Starting infrastructure centralization...${NC}"
    
    # Create necessary directories
    mkdir -p "$BASE_DIR/docker/scripts"
    
    create_centralized_db_config
    update_application_configs
    create_centralized_override
    create_db_init_scripts
    create_centralized_manager
    update_existing_compose_files
    
    echo -e "\n${GREEN}🎉 Infrastructure centralization complete!${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Stop all current services: ./docker-compose-manager.sh down"
    echo "2. Start centralized infrastructure: ./docker/centralized-manager.sh start"
    echo "3. Start applications: ./docker-compose-manager.sh up applications"
    echo ""
    echo -e "${BLUE}Access points:${NC}"
    echo "- Traefik Dashboard: http://localhost:8090"
    echo "- PostgreSQL: localhost:5432"
    echo "- MySQL: localhost:3306"
    echo "- Redis: localhost:6379"
    echo "- MongoDB: localhost:27017"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi