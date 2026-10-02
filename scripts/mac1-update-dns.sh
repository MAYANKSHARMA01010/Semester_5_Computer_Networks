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

require_command brew
require_command dnsmasq
require_command ifconfig
require_command lsof
require_sudo

require_local_ipv4 MAC_IP_1_DNS

# ============================================================
# Paths
# ============================================================

DNS_REPO_CONFIG="${ROOT_DIR}/dns/dnsmasq.conf"

BREW_PREFIX="$(brew --prefix)"
DNSMASQ_LIVE_CONFIG="${BREW_PREFIX}/etc/dnsmasq.conf"

require_file "${DNS_REPO_CONFIG}"

mkdir -p "$(dirname "${DNSMASQ_LIVE_CONFIG}")"

# ============================================================
# Determine interface
# ============================================================

DNS_INTERFACE="${DNS_INTERFACE:-}"

if [[ -z "${DNS_INTERFACE}" ]]; then
    DNS_INTERFACE="$(
        route -n get default 2>/dev/null |
            awk '/interface:/{print $2; exit}'
    )"
fi

[[ -n "${DNS_INTERFACE}" ]] || \
    die "Could not determine the active network interface."

if ! ifconfig "${DNS_INTERFACE}" >/dev/null 2>&1; then
    die "Network interface '${DNS_INTERFACE}' does not exist."
fi

if ! ifconfig "${DNS_INTERFACE}" |
    awk '/inet / {print $2}' |
    grep -Fxq "${MAC_IP_1_DNS}"; then
    die "${MAC_IP_1_DNS} is not assigned to interface ${DNS_INTERFACE}."
fi

# ============================================================
# Render configuration — substitute all values from .env
# ============================================================

TMP_CONFIG="$(make_temp_file)"
trap 'cleanup_temp_file "${TMP_CONFIG}"' EXIT

cp "${DNS_REPO_CONFIG}" "${TMP_CONFIG}"

# Rewrite each directive line in full, matching by key pattern.
# This works for both __PLACEHOLDER__ tokens (first run) and
# real values (subsequent runs when IPs change).
sed -i '' \
    -e "s|^interface=.*|interface=${DNS_INTERFACE}|" \
    -e "s|^listen-address=.*|listen-address=127.0.0.1,${MAC_IP_1_DNS}|" \
    -e "s|^address=/__APP_DOMAIN__/.*|address=/${APP_DOMAIN}/${MAC_IP_2_NGINX_LOAD_BALANCER}|" \
    -e "s|^address=/__API_DOMAIN__/.*|address=/${API_DOMAIN}/${MAC_IP_2_NGINX_LOAD_BALANCER}|" \
    -e "s|^address=/${APP_DOMAIN}/.*|address=/${APP_DOMAIN}/${MAC_IP_2_NGINX_LOAD_BALANCER}|" \
    -e "s|^address=/${API_DOMAIN}/.*|address=/${API_DOMAIN}/${MAC_IP_2_NGINX_LOAD_BALANCER}|" \
    "${TMP_CONFIG}"



# ============================================================
# Validate generated dnsmasq configuration
# ============================================================

log "Testing dnsmasq configuration..."

if ! dnsmasq \
    --test \
    --conf-file="${TMP_CONFIG}" \
    >/tmp/cn-dnsmasq-test.log 2>&1; then

    cat /tmp/cn-dnsmasq-test.log >&2
    die "Generated dnsmasq configuration failed validation."
fi

rm -f /tmp/cn-dnsmasq-test.log

# ============================================================
# Backup
# ============================================================

REPO_BACKUP=""
LIVE_BACKUP=""

REPO_BACKUP="$(backup_file "${DNS_REPO_CONFIG}")"

if [[ -f "${DNSMASQ_LIVE_CONFIG}" ]]; then
    LIVE_BACKUP="$(backup_file "${DNSMASQ_LIVE_CONFIG}")"
fi

# ============================================================
# Install configuration
# ============================================================

log "Updating repository dnsmasq configuration..."

cp "${TMP_CONFIG}" "${DNS_REPO_CONFIG}"

log "Updating live Homebrew dnsmasq configuration..."

sudo install \
    -m 644 \
    "${TMP_CONFIG}" \
    "${DNSMASQ_LIVE_CONFIG}"

# ============================================================
# Restart dnsmasq
# ============================================================

log "Restarting dnsmasq..."

if ! sudo brew services restart dnsmasq; then

    warn "dnsmasq restart failed. Restoring previous configurations..."

    if [[ -n "${REPO_BACKUP}" ]]; then
        cp "${REPO_BACKUP}" "${DNS_REPO_CONFIG}"
    fi

    if [[ -n "${LIVE_BACKUP}" ]]; then
        restore_file "${LIVE_BACKUP}" "${DNSMASQ_LIVE_CONFIG}"
    fi

    die "dnsmasq was not restarted. Previous configuration restored."
fi

sleep 2

# ============================================================
# Verify DNS listener
# ============================================================

log "Checking DNS listener..."

if ! sudo lsof -nP -iUDP:"${DNS_PORT}" |
    grep -Eq "UDP ${MAC_IP_1_DNS}:${DNS_PORT}"; then

    warn "dnsmasq is not listening on ${MAC_IP_1_DNS}:${DNS_PORT}."

    show_port_owner udp "${DNS_PORT}"

    die "DNS verification failed."
fi

# ============================================================
# Verify DNS records directly
# ============================================================

require_command dig

APP_RESULT="$(dig +short @"${MAC_IP_1_DNS}" "${APP_DOMAIN}")"
API_RESULT="$(dig +short @"${MAC_IP_1_DNS}" "${API_DOMAIN}")"

[[ "${APP_RESULT}" == "${MAC_IP_2_NGINX_LOAD_BALANCER}" ]] || \
    die "DNS verification failed for ${APP_DOMAIN}: got '${APP_RESULT}'."

[[ "${API_RESULT}" == "${MAC_IP_2_NGINX_LOAD_BALANCER}" ]] || \
    die "DNS verification failed for ${API_DOMAIN}: got '${API_RESULT}'."

# ============================================================
# Success
# ============================================================

log "DNS configuration updated successfully."
log "${APP_DOMAIN} -> ${MAC_IP_2_NGINX_LOAD_BALANCER}"
log "${API_DOMAIN} -> ${MAC_IP_2_NGINX_LOAD_BALANCER}"
log "dnsmasq listening on ${MAC_IP_1_DNS}:${DNS_PORT}"
