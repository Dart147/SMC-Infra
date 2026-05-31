#!/bin/bash

# Script to reload Prometheus configuration
# This script triggers Prometheus to reload its configuration and alert rules
# Usage: 
#   ./reload-prometheus.sh                    # Reload via container (default)
#   ./reload-prometheus.sh http://prometheus:9090  # Reload via URL

set -e

# Check if URL is provided as argument
if [ -n "$1" ]; then
    PROMETHEUS_URL="$1"
    echo "Reloading Prometheus configuration via URL: ${PROMETHEUS_URL}..."
    
    # Send POST request to Prometheus reload endpoint
    if curl -X POST "${PROMETHEUS_URL}/-/reload" -f -s -o /dev/null; then
        echo "✓ Prometheus configuration reloaded successfully"
        echo "  Alert rules and targets will be reloaded within a few seconds"
    else
        echo "✗ Failed to reload Prometheus configuration"
        echo "  Make sure Prometheus is running and --web.enable-lifecycle is enabled"
        exit 1
    fi
else
    # Default: reload via container exec
    CONTAINER_NAME="prometheus"
    
    echo "Reloading Prometheus configuration via container: ${CONTAINER_NAME}..."
    
    # Check if container exists and is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "✗ Container '${CONTAINER_NAME}' is not running"
        exit 1
    fi
    
    # Send reload request via container exec
    if docker exec "${CONTAINER_NAME}" wget --quiet --spider --post-data="" "http://localhost:9090/-/reload"; then
        echo "✓ Prometheus configuration reloaded successfully"
        echo "  Alert rules and targets will be reloaded within a few seconds"
    else
        echo "✗ Failed to reload Prometheus configuration"
        echo "  Make sure Prometheus container has --web.enable-lifecycle enabled"
        exit 1
    fi
fi
