#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_info() {
    echo -e ":: ${BLUE}$1${NC}"
}

log_success() {
    echo -e ":: ${GREEN}$1${NC}"
}

log_error() {
    echo -e "${RED}==> [ERROR] $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}==> [WARNING] $1${NC}"
}

log_step() {
    echo -e ":: ${GREEN}$1${NC}"
}
