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

require_command nginx
require_command ifconfig
require_command lsof
require_command pgrep
require_sudo

require_local_ipv4 MAC_IP_2_NGINX_LOAD_BALANCER

# ============================================================
# Paths
# ============================================================

NGINX_REPO_CONFIG="${ROOT_DIR}/nginx/network-project.conf"

BREW_PREFIX="$(brew --prefix)"
NGINX_LIVE_CONFIG="${BREW_PREFIX}/etc/nginx/servers/network-project.conf"

require_file "${NGINX_REPO_CONFIG}"

mkdir -p "$(dirname "${NGINX_LIVE_CONFIG}")"

# ============================================================
# Render upstream configuration
# ============================================================

TMP_CONFIG="$(make_temp_file)"
trap 'cleanup_temp_file "${TMP_CONFIG}"' EXIT

awk \
    -v backend_a="    server ${MAC_IP_3_BACKEND_A}:${BACKEND_A_PORT};" \
    -v backend_b="    server ${MAC_IP_4_BACKEND_B}:${BACKEND_B_PORT};" '
BEGIN {
    in_upstream = 0
    backend_index = 0
    upstream_found = 0
}

{
    if ($0 ~ /^[[:space:]]*upstream[[:space:]]+backend_pool[[:space:]]*\{/) {
        in_upstream = 1
        upstream_found = 1
        backend_index = 0

        print
        next
    }

    if (in_upstream && $0 ~ /^[[:space:]]*\}/) {
        if (backend_index == 0) {
            print backend_a
            print backend_b
        } else if (backend_index == 1) {
            print backend_b
        }

        in_upstream = 0
        print
        next
    }

    if (in_upstream &&
        $0 ~ /^[[:space:]]*server[[:space:]]+[^{};]+:[^{};]+;/) {

        backend_index++

        if (backend_index == 1) {
            print backend_a
        } else if (backend_index == 2) {
            print backend_b
        }

        next
    }

    print
}

END {
    if (!upstream_found) {
        exit 2
    }

    if (in_upstream) {
        exit 3
    }
}
' "${NGINX_REPO_CONFIG}" > "${TMP_CONFIG}"

# ============================================================
# Substitute __PLACEHOLDER__ tokens with real values from .env
# ============================================================

sed -i '' \
    -e "s|__BREW_PREFIX__|${BREW_PREFIX}|g" \
    -e "s|__MAC_IP_3_BACKEND_A__|${MAC_IP_3_BACKEND_A}|g" \
    -e "s|__MAC_IP_4_BACKEND_B__|${MAC_IP_4_BACKEND_B}|g" \
    -e "s|__BACKEND_A_PORT__|${BACKEND_A_PORT}|g" \
    -e "s|__BACKEND_B_PORT__|${BACKEND_B_PORT}|g" \
    "${TMP_CONFIG}"

log "Generated NGINX configuration."

# ============================================================
# Auto-generate self-signed SSL certificate if missing
# ============================================================

SSL_DIR="${BREW_PREFIX}/etc/nginx/ssl"
SSL_CERT="${SSL_DIR}/team1.crt"
SSL_KEY="${SSL_DIR}/team1.key"

if [[ ! -f "${SSL_CERT}" || ! -f "${SSL_KEY}" ]]; then
    log "SSL certificate not found — generating self-signed cert..."
    sudo mkdir -p "${SSL_DIR}"
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "${SSL_KEY}" \
        -out "${SSL_CERT}" \
        -subj "/CN=team1.test/O=ComputerNetworksProject" \
        2>/dev/null
    log "Self-signed certificate generated at ${SSL_CERT}"
fi

# ============================================================
# Backup
# ============================================================

REPO_BACKUP=""
LIVE_BACKUP=""

REPO_BACKUP="$(backup_file "${NGINX_REPO_CONFIG}")"

if [[ -f "${NGINX_LIVE_CONFIG}" ]]; then
    LIVE_BACKUP="$(backup_file "${NGINX_LIVE_CONFIG}")"
fi

# ============================================================
# Install
# ============================================================

log "Updating repository NGINX configuration..."

cp "${TMP_CONFIG}" "${NGINX_REPO_CONFIG}"

log "Updating live NGINX configuration..."

sudo install \
    -m 644 \
    "${TMP_CONFIG}" \
    "${NGINX_LIVE_CONFIG}"

# ============================================================
# Validate NGINX
# ============================================================

log "Testing NGINX configuration..."

if ! sudo nginx -t; then

    warn "NGINX configuration validation failed."
    warn "Restoring previous configuration..."

    if [[ -n "${REPO_BACKUP}" ]]; then
        cp "${REPO_BACKUP}" "${NGINX_REPO_CONFIG}"
    fi

    if [[ -n "${LIVE_BACKUP}" ]]; then
        restore_file "${LIVE_BACKUP}" "${NGINX_LIVE_CONFIG}"
    fi

    sudo nginx -t || true

    die "Previous NGINX configuration restored."
fi

# ============================================================
# Start / reload NGINX
# ============================================================

if pgrep -x nginx >/dev/null 2>&1; then
    log "NGINX is already running. Reloading..."

    if ! sudo nginx -s reload; then

        warn "NGINX reload failed."
        warn "Restoring previous configuration..."

        if [[ -n "${REPO_BACKUP}" ]]; then
            cp "${REPO_BACKUP}" "${NGINX_REPO_CONFIG}"
        fi

        if [[ -n "${LIVE_BACKUP}" ]]; then
            restore_file "${LIVE_BACKUP}" "${NGINX_LIVE_CONFIG}"
        fi

        sudo nginx -t || true
        sudo nginx -s reload || true

        die "NGINX reload failed. Previous configuration restored."
    fi
else
    log "NGINX is not running. Starting..."

    if ! sudo nginx; then

        warn "NGINX start failed."
        warn "Restoring previous configuration..."

        if [[ -n "${REPO_BACKUP}" ]]; then
            cp "${REPO_BACKUP}" "${NGINX_REPO_CONFIG}"
        fi

        if [[ -n "${LIVE_BACKUP}" ]]; then
            restore_file "${LIVE_BACKUP}" "${NGINX_LIVE_CONFIG}"
        fi

        die "NGINX could not start. Previous configuration restored."
    fi
fi

sleep 2

# ============================================================
# Verify listener
# ============================================================

if ! sudo lsof -nP -iTCP:"${NGINX_HTTPS_PORT}" -sTCP:LISTEN |
    grep -Eq "TCP \\*:${NGINX_HTTPS_PORT}"; then

    show_port_owner tcp "${NGINX_HTTPS_PORT}"

    die "NGINX is not listening on TCP ${NGINX_HTTPS_PORT}."
fi

# ============================================================
# Verify upstream entries
# ============================================================

grep -Fq \
    "server ${MAC_IP_3_BACKEND_A}:${BACKEND_A_PORT};" \
    "${NGINX_REPO_CONFIG}" || \
    die "Backend A entry missing from NGINX configuration."

grep -Fq \
    "server ${MAC_IP_4_BACKEND_B}:${BACKEND_B_PORT};" \
    "${NGINX_REPO_CONFIG}" || \
    die "Backend B entry missing from NGINX configuration."

# ============================================================
# Success
# ============================================================

log "NGINX configuration updated successfully."
log "Backend A -> ${MAC_IP_3_BACKEND_A}:${BACKEND_A_PORT}"
log "Backend B -> ${MAC_IP_4_BACKEND_B}:${BACKEND_B_PORT}"
log "HTTPS -> ${MAC_IP_2_NGINX_LOAD_BALANCER}:${NGINX_HTTPS_PORT}"
