#!/bin/bash

# Script to fix duplicate container_name entries in docker-compose.yml files
# This fixes YAML parsing errors caused by misplaced container_name entries

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Fixing YAML syntax errors in docker-compose files...${NC}"

# Base directory
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to fix a single docker-compose.yml file
fix_compose_file() {
    local file="$1"
    local service_name="$2"
    
    echo -e "${YELLOW}📝 Fixing $file...${NC}"
    
    # Backup the original file
    cp "$file" "${file}.backup-$(date +%Y%m%d-%H%M%S)"
    
    # Create a temporary file to work with
    local temp_file=$(mktemp)
    
    # Read the file and fix the issues
    local in_service=false
    local service_found=false
    local container_name_set=false
    
    while IFS= read -r line; do
        # Check if we're starting a service definition
        if [[ "$line" =~ ^[[:space:]]*[a-zA-Z0-9_-]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*networks:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*volumes:[[:space:]]*$ ]]; then
            in_service=true
            service_found=true
            container_name_set=false
            echo "$line" >> "$temp_file"
        # Check if we're starting a top-level section (networks, volumes, etc.)
        elif [[ "$line" =~ ^[a-zA-Z] ]]; then
            in_service=false
            echo "$line" >> "$temp_file"
        # If we're in a service and see a container_name line
        elif [[ "$in_service" == true ]] && [[ "$line" =~ ^[[:space:]]*container_name:[[:space:]] ]]; then
            # Only add the first container_name we encounter
            if [[ "$container_name_set" == false ]]; then
                echo "$line" >> "$temp_file"
                container_name_set=true
            fi
            # Skip all other container_name lines
        # Skip lines that are just "container_name: service-container" without proper indentation
        elif [[ "$line" =~ ^[[:space:]]*container_name:[[:space:]]*${service_name}-container[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]{2,6}container_name: ]]; then
            # Skip these malformed lines
            continue
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$file"
    
    # Replace the original file with the fixed version
    mv "$temp_file" "$file"
    
    # Validate the YAML
    if cd "$(dirname "$file")" && docker-compose config --quiet 2>/dev/null; then
        echo -e "${GREEN}✅ $file fixed and validated${NC}"
        return 0
    else
        echo -e "${RED}❌ $file still has issues${NC}"
        return 1
    fi
}

# List of applications that were failing
failing_services=(
    "applications/comfyui"
    "applications/openbb" 
    "applications/wordpress"
    "applications/rocketchat"
    "applications/metabase"
    "applications/vscode-server"
    "applications/vikunja"
    "applications/bookstack"
    "applications/ghost"
    "applications/jupyterhub"
    "applications/plausible"
    "applications/pocketbase"
    "infrastructure/airflow"
    "infrastructure/gitlab"
    "infrastructure/jenkins"
    "infrastructure/rabbitmq"
    "storage/minio"
)

# Fix each service
fixed_count=0
failed_count=0

for service_path in "${failing_services[@]}"; do
    compose_file="$BASE_DIR/docker/$service_path/docker-compose.yml"
    service_name=$(basename "$service_path")
    
    if [[ -f "$compose_file" ]]; then
        if fix_compose_file "$compose_file" "$service_name"; then
            ((fixed_count++))
        else
            ((failed_count++))
        fi
    else
        echo -e "${YELLOW}⚠️ $compose_file not found, skipping${NC}"
    fi
done

echo -e "\n${BLUE}📊 Summary:${NC}"
echo -e "${GREEN}✅ Fixed: $fixed_count files${NC}"
echo -e "${RED}❌ Failed: $failed_count files${NC}"

if [[ $failed_count -eq 0 ]]; then
    echo -e "\n${GREEN}🎉 All docker-compose.yml files have been fixed!${NC}"
    echo -e "${YELLOW}💡 You can now run ./docker-manager.sh start-all again${NC}"
else
    echo -e "\n${YELLOW}⚠️ Some files still need manual fixing${NC}"
fi