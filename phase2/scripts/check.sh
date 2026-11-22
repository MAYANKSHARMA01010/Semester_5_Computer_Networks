#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/helpers/env.sh"

url="https://$APP_DOMAIN:$NGINX_HTTPS_PORT/api/status"
http_status() {
    curl --noproxy '*' --connect-timeout 3 --max-time 8 --silent --show-error \
        --dump-header - --output /dev/null --write-out 'Connected IP: %{remote_ip}\n' "$@"
}

dns_check() {
    dig +time=2 +tries=1 +noall +comments +answer +stats "$@"
}

case "${1:-}" in
    dns)
        for resolver in "$MAC_IP_1_DNS" "$MAC_IP_4_BACKEND_B"; do
            for name in "$APP_DOMAIN" "$API_DOMAIN"; do
                printf '\n=== %s via %s ===\n' "$name" "$resolver"
                dns_check -p "$DNS_PORT" "@$resolver" "$name" A
            done
        done
        printf '\n=== Forwarding via the backup ===\n'
        dns_check -p "$DNS_PORT" "@$MAC_IP_4_BACKEND_B" example.com A
        ;;
    resolver)
        printf '\n=== Default resolver ===\n'
        name="${2:-$APP_DOMAIN}"
        require_dns_name "$name"
        dns_check "$name" A
        ;;
    cache)
        name="${2:-ttl-demo.team1.test}"
        require_dns_name "$name"
        date '+%Y-%m-%d %H:%M:%S %z'
        dscacheutil -q host -a name "$name"
        ;;
    https|repeat|headers|standby)
        ca="${2:-}"
        require_file "$ca"
        mode="$1"
        count=1
        args=(--cacert "$ca")
        case "$mode" in
            standby) args+=(--resolve "$APP_DOMAIN:$NGINX_HTTPS_PORT:$MAC_IP_3_BACKEND_A") ;;
            repeat)
                count="${3:-6}"
                [[ "$count" =~ ^[1-9][0-9]?$ ]] || die "Use a request count from 1 to 99."
                ;;
            headers)
                printf '\n=== GET response headers ===\n'
                http_status "${args[@]}" "$url"
                printf '\n=== Conditional GET ===\n'
                http_status "${args[@]}" -H 'If-None-Match: "status-v1"' "$url"
                exit
                ;;
        esac
        for ((i=1; i<=count; i++)); do
            printf '\n=== Request %d at %s ===\n' "$i" "$(date '+%Y-%m-%d %H:%M:%S %z')"
            http_status "${args[@]}" "$url"
        done
        ;;
    direct)
        failures=0
        for target in "$MAC_IP_3_BACKEND_A:$BACKEND_A_PORT" "$MAC_IP_4_BACKEND_B:$BACKEND_B_PORT"; do
            printf '\n=== Direct HTTP to %s ===\n' "$target"
            if ! http_status "http://$target/api/status"; then
                failures=$((failures + 1))
            fi
        done
        [[ "$failures" == 0 ]]
        ;;
    troubleshoot)
        ca="${2:-}"
        require_file "$ca"
        printf '\n=== 1. DNS (system lookup) ===\n'
        addresses="$(dscacheutil -q host -a name "$APP_DOMAIN")"
        printf '%s\n' "$addresses"
        edge="$(printf '%s\n' "$addresses" | awk '/^ip_address:/ && !seen++ { print $2 }')"
        is_valid_ipv4 "$edge" || die "System DNS did not return an IPv4 address."
        printf '\n=== 2. TCP to %s:%s ===\n' "$edge" "$NGINX_HTTPS_PORT"
        nc -vz -G 3 "$edge" "$NGINX_HTTPS_PORT"
        printf '\n=== 3. TLS certificate and hostname ===\n'
        openssl s_client -connect "$edge:$NGINX_HTTPS_PORT" -servername "$APP_DOMAIN" \
            -CAfile "$ca" -verify_hostname "$APP_DOMAIN" -verify_return_error -brief </dev/null
        printf '\n=== 4. HTTP status, headers and JSON ===\n'
        curl --noproxy '*' --connect-timeout 3 --max-time 8 --silent --show-error \
            --fail-with-body --include --cacert "$ca" --resolve "$APP_DOMAIN:$NGINX_HTTPS_PORT:$edge" "$url"
        ;;
    *) die "Usage: $0 dns|resolver|cache|https|repeat|headers|standby|direct|troubleshoot [CERT|NAME] [COUNT]" ;;
esac
