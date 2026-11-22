#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/helpers/env.sh"

case "${1:-}" in
    primary) dns_ip="$MAC_IP_1_DNS" ;;
    backup) dns_ip="$MAC_IP_4_BACKEND_B" ;;
    *) die "Usage: $0 primary|backup baseline|standby [TTL_RECORD_IP] [render|serve]" ;;
esac

case "${2:-}" in
    baseline) app_ip="$MAC_IP_2_NGINX_LOAD_BALANCER" ;;
    standby) app_ip="$MAC_IP_3_BACKEND_A" ;;
    *) die "Specify baseline or standby."
esac

ttl_ip="${3:-$MAC_IP_2_NGINX_LOAD_BALANCER}"
forwarder="${CN_DNS_FORWARDER:-1.1.1.1}"
is_valid_ipv4 "$ttl_ip" || die "Invalid TTL record address."
is_valid_ipv4 "$forwarder" || die "Invalid DNS forwarder."

render() {
    sed -e "s/@INTERFACE@/$DNS_INTERFACE/g" -e "s/@DNS_IP@/$dns_ip/g" \
        -e "s/@DNS_PORT@/$DNS_PORT/g" -e "s/@FORWARDER@/$forwarder/g" \
        -e "s/@APP_DOMAIN@/$APP_DOMAIN/g" -e "s/@API_DOMAIN@/$API_DOMAIN/g" \
        -e "s/@APP_IP@/$app_ip/g" -e "s/@PRIMARY_IP@/$MAC_IP_2_NGINX_LOAD_BALANCER/g" \
        -e "s/@TTL_IP@/$ttl_ip/g" "$PHASE2/config/dnsmasq.conf.in"
}

case "${4:-render}" in
    render) render ;;
    serve)
        require_wifi_ip "$dns_ip"
        require_command dnsmasq
        config="$(make_temp_file)"
        trap 'cleanup_temp_file "$config"' EXIT
        render > "$config"
        dnsmasq --test --conf-file="$config"
        sudo "$(command -v dnsmasq)" --keep-in-foreground --conf-file="$config"
        ;;
    *) die "Specify render or serve." ;;
esac
