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

require_command networksetup
require_command dscacheutil
require_command dig
require_command lsof
require_sudo

validate_ip MAC_IP_1_DNS

require_network_service "${WIFI_SERVICE}"

# ============================================================
# Detect Cloudflare WARP DNS interception
# ============================================================

CLOUDFLARE_DNS="$(sudo lsof -nP -iUDP:53 2>/dev/null |
    grep -Ei 'Cloudflar|1dot1dot1dot1|warp' || true)"

if [[ -n "${CLOUDFLARE_DNS}" ]]; then
    warn "Cloudflare WARP is currently intercepting DNS on this Mac."
    printf '%s\n' "${CLOUDFLARE_DNS}" >&2
    die "Disable/stop Cloudflare WARP before configuring the project DNS."
fi

# ============================================================
# Configure DNS
# ============================================================

log "Setting ${WIFI_SERVICE} DNS to ${MAC_IP_1_DNS}..."

sudo networksetup \
    -setdnsservers \
    "${WIFI_SERVICE}" \
    "${MAC_IP_1_DNS}"

# ============================================================
# Flush local DNS caches
# ============================================================

log "Flushing macOS DNS cache..."

flush_macos_dns_cache

sleep 2

# ============================================================
# Verify configured DNS
# ============================================================

CONFIGURED_DNS="$(networksetup -getdnsservers "${WIFI_SERVICE}" 2>/dev/null || true)"

printf '%s\n' "${CONFIGURED_DNS}"

if ! printf '%s\n' "${CONFIGURED_DNS}" |
    grep -Fxq "${MAC_IP_1_DNS}"; then

    die "macOS did not retain DNS server ${MAC_IP_1_DNS}."
fi

# ============================================================
# Verify direct DNS query
# ============================================================

log "Testing direct DNS resolution..."

DIRECT_RESULT="$(dig +short @"${MAC_IP_1_DNS}" "${APP_DOMAIN}")"

[[ "${DIRECT_RESULT}" == "${MAC_IP_2_NGINX_LOAD_BALANCER}" ]] || \
    die "Direct DNS query failed: ${APP_DOMAIN} -> '${DIRECT_RESULT}'."

# ============================================================
# Verify system resolver
# ============================================================

log "Testing system DNS resolution..."

SYSTEM_OUTPUT="$(dig "${APP_DOMAIN}" 2>&1 || true)"

printf '%s\n' "${SYSTEM_OUTPUT}"

SYSTEM_RESULT="$(printf '%s\n' "${SYSTEM_OUTPUT}" |
    awk '/^[^;].*[[:space:]]IN[[:space:]]A[[:space:]]/ {print $NF; exit}')"

if [[ "${SYSTEM_RESULT}" != "${MAC_IP_2_NGINX_LOAD_BALANCER}" ]]; then

    warn "Direct DNS works, but the system resolver did not return the expected address."
    warn "Check:"
    warn "  scutil --dns"
    warn "  sudo lsof -nP -iUDP:53"

    die "System DNS verification failed."
fi

# ============================================================
# Success
# ============================================================

log "Client DNS configured successfully."
log "${APP_DOMAIN} -> ${MAC_IP_2_NGINX_LOAD_BALANCER}"
log "DNS server -> ${MAC_IP_1_DNS}"
