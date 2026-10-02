#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "============================================================"
echo " Mac 2 — Full Setup"
echo " Role: NGINX / Reverse Proxy / Load Balancer"
echo "============================================================"
echo ""

echo ">>> Step 1/2 — Updating NGINX upstream configuration..."
echo ""
bash "${SCRIPT_DIR}/mac2-update-nginx.sh"

echo ""
echo ">>> Step 2/2 — Configuring client DNS to point at Mac 1..."
echo ""
bash "${SCRIPT_DIR}/configure-client-dns.sh"

echo ""
echo "============================================================"
echo " Mac 2 setup complete."
echo "============================================================"
