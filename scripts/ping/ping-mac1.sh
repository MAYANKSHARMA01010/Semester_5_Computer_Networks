#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/common.sh"

# ============================================================
# Load environment
# ============================================================

load_environment
validate_project_environment

require_command ping
require_command ifconfig

validate_ip MAC_IP_1_DNS
validate_ip MAC_IP_2_NGINX_LOAD_BALANCER
validate_ip MAC_IP_3_BACKEND_A
validate_ip MAC_IP_4_BACKEND_B

require_local_ipv4 MAC_IP_1_DNS

# ============================================================
# Output
# ============================================================

EVIDENCE_DIR="${ROOT_DIR}/evidence/LAN"
OUTPUT_FILE="${EVIDENCE_DIR}/ping-Mac1-to-all.txt"

mkdir -p "${EVIDENCE_DIR}"

# ============================================================
# Start evidence capture
# ============================================================

exec > >(tee "${OUTPUT_FILE}") 2>&1

echo "============================================================"
echo "Computer Networks Project - LAN Connectivity Evidence"
echo "============================================================"
echo "Machine        : Mac 1"
echo "Role           : Private DNS Server"
echo "Local IP       : ${MAC_IP_1_DNS}"
echo "Date           : $(date)"
echo "============================================================"
echo

declare -A TARGETS=(
    ["Mac 2 - NGINX"]="${MAC_IP_2_NGINX_LOAD_BALANCER}"
    ["Mac 3 - Backend A"]="${MAC_IP_3_BACKEND_A}"
    ["Mac 4 - Backend B"]="${MAC_IP_4_BACKEND_B}"
)

FAILED=0

for TARGET_NAME in "${!TARGETS[@]}"; do
    TARGET_IP="${TARGETS[$TARGET_NAME]}"

    echo "------------------------------------------------------------"
    echo "Testing ${TARGET_NAME}"
    echo "Target IP: ${TARGET_IP}"
    echo "------------------------------------------------------------"

    if ping -c 4 "${TARGET_IP}"; then
        echo "RESULT: PASS"
    else
        echo "RESULT: FAIL"
        FAILED=1
    fi

    echo
done

echo "============================================================"
echo "Mac 1 LAN TEST COMPLETE"
echo "Evidence saved to:"
echo "${OUTPUT_FILE}"
echo "============================================================"

if (( FAILED != 0 )); then
    exit 1
fi

exit 0
