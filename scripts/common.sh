#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

# ============================================================
# Project paths
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"
BACKUP_DIR="${BACKUP_DIR:-${ROOT_DIR}/.runtime-backups}"

# Keep generated files private by default.
umask 077

# ============================================================
# Logging
# ============================================================

log() {
    printf '[INFO] %s\n' "$*"
}

warn() {
    printf '[WARN] %s\n' "$*" >&2
}

die() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

error_trap() {
    local exit_code=$?
    printf '[ERROR] Command failed at %s:%s\n' \
        "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}" \
        "${BASH_LINENO[0]:-unknown}" >&2
    exit "${exit_code}"
}

trap error_trap ERR

# ============================================================
# Basic helpers
# ============================================================

require_command() {
    local command_name="$1"

    command -v "${command_name}" >/dev/null 2>&1 || \
        die "Required command '${command_name}' was not found."
}

require_file() {
    local file_path="$1"

    [[ -f "${file_path}" ]] || \
        die "Required file does not exist: ${file_path}"
}

require_directory() {
    local directory_path="$1"

    [[ -d "${directory_path}" ]] || \
        die "Required directory does not exist: ${directory_path}"
}

ensure_backup_dir() {
    mkdir -p "${BACKUP_DIR}"
}

timestamp() {
    date '+%Y%m%d-%H%M%S'
}

# ============================================================
# Environment
# ============================================================

load_environment() {
    require_file "${ENV_FILE}"

    # shellcheck disable=SC1090
    set -a
    source "${ENV_FILE}"
    set +a
}

require_env() {
    local variable_name="$1"

    if [[ -z "${!variable_name:-}" ]]; then
        die "Environment variable '${variable_name}' is missing or empty."
    fi
}

# ============================================================
# Validation
# ============================================================

is_valid_ipv4() {
    local ip="$1"
    local IFS='.'
    local -a octets

    read -r -a octets <<< "${ip}"

    [[ "${#octets[@]}" -eq 4 ]] || return 1

    local octet

    for octet in "${octets[@]}"; do
        [[ "${octet}" =~ ^[0-9]+$ ]] || return 1
        (( octet >= 0 && octet <= 255 )) || return 1

        # Reject values like 01 to avoid ambiguity.
        if [[ "${#octet}" -gt 1 && "${octet}" == 0* ]]; then
            return 1
        fi
    done

    return 0
}

validate_ip() {
    local variable_name="$1"

    require_env "${variable_name}"

    if ! is_valid_ipv4 "${!variable_name}"; then
        die "${variable_name}='${!variable_name}' is not a valid IPv4 address."
    fi
}

validate_port() {
    local variable_name="$1"

    require_env "${variable_name}"

    local port="${!variable_name}"

    [[ "${port}" =~ ^[0-9]+$ ]] || \
        die "${variable_name}='${port}' is not a valid port."

    (( port >= 1 && port <= 65535 )) || \
        die "${variable_name}='${port}' must be between 1 and 65535."
}

validate_project_environment() {
    validate_ip MAC_IP_1_DNS
    validate_ip MAC_IP_2_NGINX_LOAD_BALANCER
    validate_ip MAC_IP_3_BACKEND_A
    validate_ip MAC_IP_4_BACKEND_B

    validate_port DNS_PORT
    validate_port NGINX_HTTPS_PORT
    validate_port BACKEND_A_PORT
    validate_port BACKEND_B_PORT

    require_env APP_DOMAIN
    require_env API_DOMAIN
    require_env WIFI_SERVICE
    require_env PYTHON_BIN
}

# ============================================================
# macOS helpers
# ============================================================

is_local_ipv4() {
    local target_ip="$1"

    if ifconfig | awk '/inet / {print $2}' | grep -Fxq "${target_ip}"; then
        return 0
    fi

    return 1
}

require_local_ipv4() {
    local variable_name="$1"
    local ip="${!variable_name}"

    is_local_ipv4 "${ip}" || \
        die "${variable_name}=${ip} is not assigned to this Mac."
}

network_service_exists() {
    local service_name="$1"

    networksetup -listallnetworkservices 2>/dev/null |
        sed '1d; s/^\*//' |
        grep -Fxq "${service_name}"
}

require_network_service() {
    local service_name="$1"

    network_service_exists "${service_name}" || \
        die "Network service '${service_name}' does not exist on this Mac."
}

# ============================================================
# Backup helpers
# ============================================================

backup_file() {
    local source_path="$1"

    [[ -f "${source_path}" ]] || return 0

    ensure_backup_dir

    local backup_path
    backup_path="${BACKUP_DIR}/$(basename "${source_path}").$(timestamp).bak"

    sudo cp -p "${source_path}" "${backup_path}"
    sudo chown "$(id -u):$(id -g)" "${backup_path}"

    # Print log to stderr so that callers using $(...) capture only the path.
    printf '[INFO] Backup created: %s\n' "${backup_path}" >&2

    printf '%s\n' "${backup_path}"
}

restore_file() {
    local backup_path="$1"
    local destination_path="$2"

    [[ -f "${backup_path}" ]] || \
        die "Backup file not found: ${backup_path}"

    sudo cp -p "${backup_path}" "${destination_path}"
}

# ============================================================
# Temporary files
# ============================================================

make_temp_file() {
    mktemp "${TMPDIR:-/tmp}/cn-project.XXXXXX"
}

cleanup_temp_file() {
    local file_path="${1:-}"

    if [[ -n "${file_path}" && -f "${file_path}" ]]; then
        rm -f "${file_path}"
    fi
}

# ============================================================
# Ports / processes
# ============================================================

port_is_listening() {
    local protocol="$1"
    local port="$2"

    if [[ "${protocol}" == "tcp" ]]; then
        sudo lsof -nP -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1
    else
        sudo lsof -nP -iUDP:"${port}" >/dev/null 2>&1
    fi
}

show_port_owner() {
    local protocol="$1"
    local port="$2"

    if [[ "${protocol}" == "tcp" ]]; then
        sudo lsof -nP -iTCP:"${port}" -sTCP:LISTEN || true
    else
        sudo lsof -nP -iUDP:"${port}" || true
    fi
}

# ============================================================
# Privilege
# ============================================================

require_sudo() {
    sudo -v
}

# ============================================================
# Service helpers
# ============================================================

flush_macos_dns_cache() {
    dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
}

# ============================================================
# End
# ============================================================
