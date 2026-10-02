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
# Evidence output
# ============================================================

EVIDENCE_DIR="${ROOT_DIR}/evidence/LAN"
OUTPUT_FILE="${EVIDENCE_DIR}/ping-Mac1-to-all.txt"

mkdir -p "${EVIDENCE_DIR}"

exec > >(tee "${OUTPUT_FILE}") 2>&1

# ============================================================
# Header
# ============================================================

echo "============================================================"
echo " Computer Networks Project — LAN Connectivity Evidence"
echo "============================================================"
echo " Source machine : Mac 1"
echo " Role           : Private DNS Server"
echo " Source IP      : ${MAC_IP_1_DNS}"
echo " Date / Time    : $(date)"
echo "============================================================"
echo ""

# ============================================================
# Targets (parallel arrays — no associative array / set -u clash)
# ============================================================

TARGET_NAMES=(
    "Mac 2 — NGINX / Load Balancer"
    "Mac 3 — Backend A"
    "Mac 4 — Backend B"
)

TARGET_IPS=(
    "${MAC_IP_2_NGINX_LOAD_BALANCER}"
    "${MAC_IP_3_BACKEND_A}"
    "${MAC_IP_4_BACKEND_B}"
)

FAILED=0
PASS_COUNT=0
FAIL_COUNT=0

for i in "${!TARGET_NAMES[@]}"; do
    TARGET_NAME="${TARGET_NAMES[$i]}"
    TARGET_IP="${TARGET_IPS[$i]}"

    echo "------------------------------------------------------------"
    echo " Target : ${TARGET_NAME}"
    echo " IP     : ${TARGET_IP}"
    echo "------------------------------------------------------------"

    if ping -c 4 "${TARGET_IP}"; then
        echo ""
        echo " >>> RESULT : PASS — ${TARGET_NAME} (${TARGET_IP}) is reachable"
        PASS_COUNT=$(( PASS_COUNT + 1 ))
    else
        echo ""
        echo " >>> RESULT : FAIL — ${TARGET_NAME} (${TARGET_IP}) is UNREACHABLE"
        FAIL_COUNT=$(( FAIL_COUNT + 1 ))
        FAILED=1
    fi

    echo ""
done

# ============================================================
# Summary
# ============================================================

echo "============================================================"
echo " SUMMARY — Mac 1 → all machines"
echo "============================================================"
echo " Source IP : ${MAC_IP_1_DNS}  (Mac 1 — DNS Server)"
echo " Passed    : ${PASS_COUNT} / 3"
echo " Failed    : ${FAIL_COUNT} / 3"
echo " Status    : $([ "${FAILED}" -eq 0 ] && echo "ALL PASS" || echo "SOME FAILURES — check above")"
echo "============================================================"
echo " Evidence saved to: ${OUTPUT_FILE}"
echo "============================================================"

exit "${FAILED}"
