#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "============================================================"
echo " Mac 4 — Full Setup"
echo " Role: Backend B (port 3002)"
echo "============================================================"
echo ""

echo ">>> Step 1/2 — Configuring client DNS to point at Mac 1..."
echo ""
bash "${SCRIPT_DIR}/helpers/configure-client-dns.sh"

echo ""
echo ">>> Step 2/2 — Starting Backend B..."
echo ""
bash "${SCRIPT_DIR}/helpers/mac4-start-backend.sh"

echo ""
echo "============================================================"
echo " Mac 4 setup complete."
echo "============================================================"
