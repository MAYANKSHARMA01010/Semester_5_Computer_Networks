#!/usr/bin/env bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../phase1/scripts/helpers" && pwd)/common.sh"
# shellcheck disable=SC2034
PHASE2="${REPO_DIR}/phase2"
export PATH="/opt/homebrew/sbin:/usr/local/sbin:$PATH"
load_environment
validate_project_environment
require_env DNS_INTERFACE
[[ "$DNS_INTERFACE" =~ ^[[:alnum:]_]+$ ]] || die "Invalid DNS_INTERFACE."
for domain in "$APP_DOMAIN" "$API_DOMAIN"; do
    [[ "$domain" =~ ^[a-zA-Z0-9.-]+\.team1\.test$ ]] || die "Expected a name under team1.test."
done

require_wifi_ip() {
    local expected="$1"
    [[ "$(ipconfig getifaddr "$DNS_INTERFACE")" == "$expected" ]] ||
        die "$DNS_INTERFACE must have address $expected. Check .env and the assigned Mac."
}

require_dns_name() {
    [[ "$1" =~ ^[a-zA-Z0-9.-]+\.team1\.test$ ]] || die "Invalid project name."
}
