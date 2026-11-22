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

validate_ip MAC_IP_3_BACKEND_A
validate_port BACKEND_A_PORT

require_local_ipv4 MAC_IP_3_BACKEND_A

# ============================================================
# Backend path
# ============================================================

BACKEND_SCRIPT="${ROOT_DIR}/backend_a/server.py"

require_file "${BACKEND_SCRIPT}"

# ============================================================
# Check whether the port is already in use
# ============================================================

if port_is_listening tcp "${BACKEND_A_PORT}"; then

    log "TCP port ${BACKEND_A_PORT} is already listening."

    show_port_owner tcp "${BACKEND_A_PORT}"

    if curl \
        --silent \
        --show-error \
        --fail \
        --connect-timeout 2 \
        "http://${MAC_IP_3_BACKEND_A}:${BACKEND_A_PORT}/" \
        >/tmp/cn-backend-a-health.json 2>/dev/null; then

        if grep -q '"backend"[[:space:]]*:[[:space:]]*"A"' \
            /tmp/cn-backend-a-health.json; then

            cat /tmp/cn-backend-a-health.json
            rm -f /tmp/cn-backend-a-health.json

            log "Backend A is already running correctly."
            exit 0
        fi
    fi

    rm -f /tmp/cn-backend-a-health.json

    die "Port ${BACKEND_A_PORT} is occupied by another service."
fi

# ============================================================
# Start backend
# ============================================================

cd "${ROOT_DIR}"

log "Starting Backend A..."
log "Expected LAN IP: ${MAC_IP_3_BACKEND_A}"
log "Port: ${BACKEND_A_PORT}"

exec "${PYTHON_BIN}" "${BACKEND_SCRIPT}"
