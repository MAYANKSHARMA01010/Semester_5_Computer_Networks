#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/helpers/env.sh"

case "${1:-show}" in
    show) networksetup -getdnsservers "$WIFI_SERVICE" ;;
    set)
        require_network_service "$WIFI_SERVICE"
        sudo networksetup -setdnsservers "$WIFI_SERVICE" "$MAC_IP_1_DNS" "$MAC_IP_4_BACKEND_B"
        networksetup -getdnsservers "$WIFI_SERVICE"
        ;;
    flush) flush_macos_dns_cache ;;
    *) die "Usage: $0 show|set|flush" ;;
esac
