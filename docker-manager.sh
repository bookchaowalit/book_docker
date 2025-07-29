#!/bin/bash

# Wrapper script for docker-compose-manager.sh
# This script allows you to run the docker manager from the root directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_MANAGER="$SCRIPT_DIR/docker/docker-compose-manager.sh"

if [ ! -f "$DOCKER_MANAGER" ]; then
    echo "Error: docker-compose-manager.sh not found at $DOCKER_MANAGER"
    exit 1
fi

# Pass all arguments to the docker-compose-manager script
exec "$DOCKER_MANAGER" "$@"
