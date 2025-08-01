#!/bin/bash

# Scheduled Docker Cleanup Script
# This script performs regular maintenance cleanup of Docker resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$BASE_DIR/logs/cleanup-$(date +%Y%m%d-%H%M%S).log"

# Create logs directory
mkdir -p "$BASE_DIR/logs"

# Function to log messages
log_message() {
    local message="$1"
    echo -e "$message" | tee -a "$LOG_FILE"
}

# Function to show cleanup schedule options
show_cleanup_schedule() {
    echo -e "${BLUE}🕒 Docker Cleanup Scheduling Options${NC}"
    echo "=================================="
    echo ""
    echo "1. Daily Cleanup (Recommended)"
    echo "   - Runs intelligent cleanup every day at 2 AM"
    echo "   - Safe cleanup of unused containers, networks, and build cache"
    echo ""
    echo "2. Weekly Deep Cleanup"
    echo "   - Runs aggressive cleanup every Sunday at 3 AM"
    echo "   - Removes unused images and performs volume analysis"
    echo ""
    echo "3. Manual Cleanup"
    echo "   - Run cleanup commands manually when needed"
    echo "   - Full control over what gets cleaned"
    echo ""
    echo "4. Setup Automatic Cleanup"
    echo "   - Configure cron jobs for automated cleanup"
    echo ""
}

# Function to setup cron jobs
setup_cron_jobs() {
    echo -e "${BLUE}⚙️ Setting up automatic cleanup cron jobs...${NC}"
    
    # Check if cron is available
    if ! command -v crontab &> /dev/null; then
        echo -e "${RED}✗ Cron is not available on this system${NC}"
        return 1
    fi
    
    # Create temporary cron file
    local temp_cron=$(mktemp)
    
    # Get existing cron jobs (if any)
    crontab -l 2>/dev/null > "$temp_cron" || true
    
    # Remove existing docker cleanup jobs
    grep -v "docker-cleanup" "$temp_cron" > "${temp_cron}.new" || true
    mv "${temp_cron}.new" "$temp_cron"
    
    # Add new cleanup jobs
    echo "# Docker Infrastructure Cleanup Jobs" >> "$temp_cron"
    echo "0 2 * * * $BASE_DIR/scripts/scheduled-cleanup.sh daily >> $BASE_DIR/logs/daily-cleanup.log 2>&1" >> "$temp_cron"
    echo "0 3 * * 0 $BASE_DIR/scripts/scheduled-cleanup.sh weekly >> $BASE_DIR/logs/weekly-cleanup.log 2>&1" >> "$temp_cron"
    
    # Install the new cron jobs
    crontab "$temp_cron"
    rm "$temp_cron"
    
    echo -e "${GREEN}✅ Cron jobs installed successfully!${NC}"
    echo ""
    echo "Scheduled cleanup jobs:"
    echo "  - Daily cleanup: Every day at 2:00 AM"
    echo "  - Weekly deep cleanup: Every Sunday at 3:00 AM"
    echo ""
    echo "To view logs:"
    echo "  tail -f $BASE_DIR/logs/daily-cleanup.log"
    echo "  tail -f $BASE_DIR/logs/weekly-cleanup.log"
}

# Function to perform daily cleanup
daily_cleanup() {
    log_message "${BLUE}🧹 Daily Docker Cleanup - $(date)${NC}"
    log_message "=================================="
    
    # Show usage before cleanup
    log_message "${YELLOW}📊 Docker usage before cleanup:${NC}"
    docker system df | tee -a "$LOG_FILE"
    
    # Perform safe cleanup
    log_message "\n${YELLOW}1. Removing stopped containers...${NC}"
    local stopped_containers=$(docker container prune -f 2>&1 | tee -a "$LOG_FILE")
    
    log_message "\n${YELLOW}2. Removing dangling images...${NC}"
    local dangling_images=$(docker image prune -f 2>&1 | tee -a "$LOG_FILE")
    
    log_message "\n${YELLOW}3. Removing unused networks...${NC}"
    local unused_networks=$(docker network prune -f 2>&1 | tee -a "$LOG_FILE")
    
    log_message "\n${YELLOW}4. Cleaning build cache...${NC}"
    docker builder prune -f >/dev/null 2>&1
    
    # Show usage after cleanup
    log_message "\n${YELLOW}📊 Docker usage after cleanup:${NC}"
    docker system df | tee -a "$LOG_FILE"
    
    log_message "\n${GREEN}✅ Daily cleanup completed - $(date)${NC}"
}

# Function to perform weekly deep cleanup
weekly_cleanup() {
    log_message "${BLUE}🧹 Weekly Deep Docker Cleanup - $(date)${NC}"
    log_message "=================================="
    
    # Show usage before cleanup
    log_message "${YELLOW}📊 Docker usage before cleanup:${NC}"
    docker system df | tee -a "$LOG_FILE"
    
    # Perform comprehensive cleanup
    log_message "\n${YELLOW}1. Removing all unused containers...${NC}"
    docker container prune -f 2>&1 | tee -a "$LOG_FILE"
    
    log_message "\n${YELLOW}2. Removing unused images (not just dangling)...${NC}"
    docker image prune -a -f 2>&1 | tee -a "$LOG_FILE"
    
    log_message "\n${YELLOW}3. Removing unused networks...${NC}"
    docker network prune -f 2>&1 | tee -a "$LOG_FILE"
    
    log_message "\n${YELLOW}4. Cleaning all build cache...${NC}"
    docker builder prune -a -f 2>&1 | tee -a "$LOG_FILE"
    
    # Analyze volumes (but don't auto-remove for safety)
    log_message "\n${YELLOW}5. Analyzing volumes...${NC}"
    local total_volumes=$(docker volume ls -q | wc -l)
    local unused_volumes=$(docker volume ls --filter dangling=true -q | wc -l)
    log_message "Total volumes: $total_volumes, Unused: $unused_volumes"
    
    if [[ $unused_volumes -gt 0 ]]; then
        log_message "${YELLOW}⚠️ Found $unused_volumes unused volumes. Run manual cleanup to review.${NC}"
    fi
    
    # Show usage after cleanup
    log_message "\n${YELLOW}📊 Docker usage after cleanup:${NC}"
    docker system df | tee -a "$LOG_FILE"
    
    log_message "\n${GREEN}✅ Weekly deep cleanup completed - $(date)${NC}"
}

# Function to show cleanup statistics
show_cleanup_stats() {
    echo -e "${BLUE}📊 Cleanup Statistics${NC}"
    echo "=================================="
    
    if [[ -d "$BASE_DIR/logs" ]]; then
        echo -e "${YELLOW}Recent cleanup logs:${NC}"
        ls -la "$BASE_DIR/logs/"cleanup-*.log 2>/dev/null | tail -5 || echo "No cleanup logs found"
        
        echo -e "\n${YELLOW}Disk space saved (last 7 days):${NC}"
        # This would require more complex parsing of logs
        echo "Check individual log files for detailed savings information"
    else
        echo "No cleanup logs directory found"
    fi
    
    echo -e "\n${YELLOW}Current Docker usage:${NC}"
    docker system df
}

# Main function
main() {
    case "${1:-help}" in
        "daily")
            daily_cleanup
            ;;
        "weekly")
            weekly_cleanup
            ;;
        "setup-cron")
            setup_cron_jobs
            ;;
        "schedule")
            show_cleanup_schedule
            ;;
        "stats")
            show_cleanup_stats
            ;;
        "help"|*)
            echo "Usage: $0 [COMMAND]"
            echo ""
            echo "Commands:"
            echo "  daily       - Perform daily safe cleanup"
            echo "  weekly      - Perform weekly deep cleanup"
            echo "  setup-cron  - Setup automatic cleanup cron jobs"
            echo "  schedule    - Show cleanup scheduling options"
            echo "  stats       - Show cleanup statistics"
            echo "  help        - Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 daily        # Run daily cleanup now"
            echo "  $0 setup-cron   # Setup automatic cleanup"
            echo "  $0 stats        # View cleanup statistics"
            ;;
    esac
}

# Run main function
main "$@"