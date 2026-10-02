#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

# ============================================================
# Load / validate environment
# ============================================================

load_environment
validate_project_environment

require_command ifconfig
require_command lsof
require_command curl
require_sudo

validate_ip MAC_IP_4_BACKEND_B
validate_port BACKEND_B_PORT

require_local_ipv4 MAC_IP_4_BACKEND_B

# ============================================================
# Backend path
# ============================================================

BACKEND_SCRIPT="${ROOT_DIR}/backend-b/server.py"

require_file "${BACKEND_SCRIPT}"

# ============================================================
# Check whether the port is already in use
# ============================================================

if port_is_listening tcp "${BACKEND_B_PORT}"; then

    log "TCP port ${BACKEND_B_PORT} is already listening."

    show_port_owner tcp "${BACKEND_B_PORT}"

    if curl \
        --silent \
        --show-error \
        --fail \
        --connect-timeout 2 \
        "http://${MAC_IP_4_BACKEND_B}:${BACKEND_B_PORT}/" \
        >/tmp/cn-backend-b-health.json 2>/dev/null; then

        if grep -q '"backend"[[:space:]]*:[[:space:]]*"B"' \
            /tmp/cn-backend-b-health.json; then

            cat /tmp/cn-backend-b-health.json
            rm -f /tmp/cn-backend-b-health.json

            log "Backend B is already running correctly."
            exit 0
        fi
    fi

    rm -f /tmp/cn-backend-b-health.json

    die "Port ${BACKEND_B_PORT} is occupied by another service."
fi

# ============================================================
# Start backend
# ============================================================

cd "${ROOT_DIR}"

log "Starting Backend B..."
log "Expected LAN IP: ${MAC_IP_4_BACKEND_B}"
log "Port: ${BACKEND_B_PORT}"

exec "${PYTHON_BIN}" "${BACKEND_SCRIPT}"
