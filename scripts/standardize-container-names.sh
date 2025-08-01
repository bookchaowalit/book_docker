#!/bin/bash

# Docker Container Name Standardization Script
# This script adds/updates container_name in all Docker Compose files to follow: [application-name]-container

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(dirname "$SCRIPT_DIR")/docker"
LOG_FILE="${SCRIPT_DIR}/container-name-standardization.log"

echo -e "${GREEN}=== Docker Container Name Standardization ===${NC}"

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case $level in
        "ERROR")
            echo -e "${RED}[$level] $message${NC}"
            ;;
        "WARN")
            echo -e "${YELLOW}[$level] $message${NC}"
            ;;
        "INFO")
            echo -e "${GREEN}[$level] $message${NC}"
            ;;
        *)
            echo "[$level] $message"
            ;;
    esac
}

# Function to get the expected container name
get_expected_container_name() {
    local app_name=$1
    echo "${app_name}-container"
}

# Function to update container names in a docker-compose.yml file
update_container_names() {
    local compose_file=$1
    local app_name=$2
    local expected_name=$(get_expected_container_name "$app_name")
    
    log "INFO" "Processing $compose_file for application: $app_name"
    
    # Create backup
    cp "$compose_file" "${compose_file}.backup-$(date +%Y%m%d-%H%M%S)"
    
    # Create temporary file
    local temp_file=$(mktemp)
    
    # Process the file
    awk -v expected_name="$expected_name" '
    BEGIN {
        in_services = 0
        in_service = 0
        service_name = ""
        service_indent = ""
        container_name_found = 0
        container_name_updated = 0
    }
    
    # Check if we are entering services section
    /^services:/ {
        in_services = 1
        print $0
        next
    }
    
    # Check if we are leaving services section (top-level key)
    /^[a-zA-Z][a-zA-Z0-9_-]*:/ && !/^services:/ && in_services {
        in_services = 0
        in_service = 0
        print $0
        next
    }
    
    # Check if we are starting a new service (inside services section)
    /^  [a-zA-Z0-9_-]+:/ && in_services {
        # If we were in a previous service and no container_name was found, add it
        if (in_service && !container_name_found) {
            print service_indent "  container_name: " expected_name
            print "[INFO] Added container_name: " expected_name " to service " service_name > "/dev/stderr"
        }
        
        in_service = 1
        service_name = $1
        gsub(/:/, "", service_name)
        service_indent = "  "
        container_name_found = 0
        container_name_updated = 0
        print $0
        next
    }
    
    # Check if this line is container_name and we are in a service
    /^    container_name:/ && in_service {
        print "    container_name: " expected_name
        print "[INFO] Updated container_name to " expected_name " for service " service_name > "/dev/stderr"
        container_name_found = 1
        container_name_updated = 1
        next
    }
    
    # Check if this is the first property after service name (to insert container_name)
    /^    [a-zA-Z0-9_-]+:/ && in_service && !container_name_found && !container_name_updated {
        print "    container_name: " expected_name
        print "[INFO] Added container_name: " expected_name " to service " service_name > "/dev/stderr"
        container_name_found = 1
        print $0
        next
    }
    
    # Regular line - just print it
    {
        print $0
    }
    
    END {
        # Handle case where the last service did not have container_name
        if (in_service && !container_name_found) {
            print service_indent "  container_name: " expected_name
            print "[INFO] Added container_name: " expected_name " to service " service_name > "/dev/stderr"
        }
    }
    ' "$compose_file" > "$temp_file"
    
    # Replace original file with updated content
    mv "$temp_file" "$compose_file"
    log "INFO" "Successfully updated $compose_file"
}

# Function to process all docker-compose files
standardize_all() {
    log "INFO" "Starting container name standardization for all Docker Compose files..."
    
    local total_files=0
    local updated_files=0
    
    # Find all docker-compose.yml files
    find "$DOCKER_DIR" -name "docker-compose.yml" -not -path "*.backup*" | while read -r compose_file; do
        total_files=$((total_files + 1))
        
        # Get application name from directory
        local app_dir=$(dirname "$compose_file")
        local app_name=$(basename "$app_dir")
        local category=$(basename "$(dirname "$app_dir")")
        
        echo -e "\n${BLUE}Processing: $category/$app_name${NC}"
        
        # Update the file
        update_container_names "$compose_file" "$app_name"
        updated_files=$((updated_files + 1))
    done
    
    echo -e "\n${GREEN}=== Standardization Complete ===${NC}"
    echo "All Docker Compose files have been processed."
    echo "Backup files created with timestamp suffix."
    echo "Check the log file for details: $LOG_FILE"
}

# Function to show current status
show_status() {
    echo -e "\n${CYAN}=== Current Container Names Status ===${NC}"
    
    find "$DOCKER_DIR" -name "docker-compose.yml" -not -path "*.backup*" | while read -r compose_file; do
        local app_dir=$(dirname "$compose_file")
        local app_name=$(basename "$app_dir")
        local category=$(basename "$(dirname "$app_dir")")
        local expected_name=$(get_expected_container_name "$app_name")
        
        echo -e "\n${YELLOW}$category/$app_name:${NC}"
        
        # Check if file has container_name
        if grep -q "container_name:" "$compose_file"; then
            local current_names=$(grep "container_name:" "$compose_file" | sed 's/.*container_name:[[:space:]]*//' | sed 's/[[:space:]]*$//')
            while IFS= read -r name; do
                if [ "$name" = "$expected_name" ]; then
                    echo -e "  ${GREEN}✓${NC} container_name: $name"
                else
                    echo -e "  ${YELLOW}⚠${NC} container_name: $name (should be: $expected_name)"
                fi
            done <<< "$current_names"
        else
            echo -e "  ${RED}✗${NC} No container_name found (should be: $expected_name)"
        fi
    done
}

# Function to show help
show_help() {
    echo -e "\n${CYAN}=== Docker Container Name Standardization Tool ===${NC}"
    echo ""
    echo "This tool adds/updates container_name in all Docker Compose files."
    echo "Pattern: [application-name]-container"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  standardize    Add/update container_name in all Docker Compose files"
    echo "  status         Show current container names status"
    echo "  help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 standardize    # Process all files"
    echo "  $0 status         # Show current status"
    echo ""
    echo "Examples of standardization:"
    echo "  baserow → baserow-container"
    echo "  nocodb → nocodb-container"
    echo "  postgres → postgres-container"
    echo "  mysql → mysql-container"
    echo ""
    echo "Log file: $LOG_FILE"
}

# Main execution
main() {
    # Initialize log file
    echo "=== Container Name Standardization Started at $(date) ===" > "$LOG_FILE"
    
    local command="${1:-status}"
    
    case "$command" in
        "standardize")
            standardize_all
            ;;
        "status")
            show_status
            ;;
        "help")
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"