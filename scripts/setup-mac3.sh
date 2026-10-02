#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "============================================================"
echo " Mac 3 — Full Setup"
echo " Role: Backend A (port 3001)"
echo "============================================================"
echo ""

echo ">>> Step 1/2 — Configuring client DNS to point at Mac 1..."
echo ""
bash "${SCRIPT_DIR}/configure-client-dns.sh"

echo ""
echo ">>> Step 2/2 — Starting Backend A..."
echo ""
bash "${SCRIPT_DIR}/mac3-start-backend.sh"

echo ""
echo "============================================================"
echo " Mac 3 setup complete."
echo "============================================================"
