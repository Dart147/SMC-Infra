#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

CORE_DIR="core/traefik"
NETWORK_NAME="smc-traefik"
CONTAINER_NAME="traefik"

check_core() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_warning "Core service '${CONTAINER_NAME}' is not running."
        log_info "Suggestion: run 'make core-up' first."
        return 1
    fi
    log_success "${CONTAINER_NAME} is running"
}

init_network() {
    if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
        log_info "${NETWORK_NAME} network already exists"
    else
        if docker network create "$NETWORK_NAME"; then
            log_success "Created ${NETWORK_NAME} network"
        else
            log_error "Failed to create ${NETWORK_NAME} network"
            return 1
        fi
    fi
}

start_core() {
    log_step "Starting core services..."

    if [[ ! -f "$CORE_DIR/.env" ]]; then
        log_error "$CORE_DIR/.env not found. Copy .env.example and fill it in."
        return 1
    fi

    (
        cd "$CORE_DIR" || exit 1
        if docker compose up -d; then
            log_success "Traefik started"
        else
            log_error "Failed to start traefik"
            return 1
        fi
    )
}

stop_core() {
    log_step "Stopping core services..."

    (
        cd "$CORE_DIR" || exit 1
        if docker compose down; then
            log_success "Traefik stopped"
        else
            log_error "Failed to stop traefik"
            return 1
        fi
    )
}

logs_core() {
    (
        cd "$CORE_DIR" || exit 1
        docker compose logs -f
    )
}

main() {
    local action="$1"

    case "$action" in
        "check")
            check_core
            ;;
        "start")
            init_network && start_core
            ;;
        "stop")
            stop_core
            ;;
        "logs")
            logs_core
            ;;
        "network-init")
            init_network
            ;;
        *)
            log_error "Unknown action: $action"
            echo "Usage: $0 {check|start|stop|logs|network-init}"
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
