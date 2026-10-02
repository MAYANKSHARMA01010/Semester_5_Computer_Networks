#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "============================================================"
echo " Mac 1 — Full Setup"
echo " Role: Private DNS Server"
echo "============================================================"
echo ""

echo ">>> Step 1/1 — Configuring dnsmasq..."
echo ""
bash "${SCRIPT_DIR}/mac1-update-dns.sh"

echo ""
echo "============================================================"
echo " Mac 1 setup complete."
echo "============================================================"
