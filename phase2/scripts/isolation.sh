#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/helpers/env.sh"

case "${1:-}" in
    a) backend_ip="$MAC_IP_3_BACKEND_A"; port="$BACKEND_A_PORT" ;;
    b) backend_ip="$MAC_IP_4_BACKEND_B"; port="$BACKEND_B_PORT" ;;
    *) die "Usage: $0 a|b render|apply|status|restore [primary|standby]" ;;
esac

anchor="com.apple/cn-backend-$1"
state="${BACKUP_DIR}/phase2-pf-$1"
sources="$MAC_IP_2_NGINX_LOAD_BALANCER"
case "${3:-primary}" in
    standby)
        [[ "$1" == b ]] || die "Standby reaches Backend A over loopback."
        sources="{ $sources, $MAC_IP_3_BACKEND_A }"
        ;;
    primary) ;;
    *) die "Specify primary or standby." ;;
esac

render() {
    sed -e "s/@INTERFACE@/$DNS_INTERFACE/g" -e "s/@EDGE_SOURCES@/$sources/g" \
        -e "s/@BACKEND_IP@/$backend_ip/g" -e "s/@BACKEND_PORT@/$port/g" \
        "$PHASE2/config/backend.pf.in"
}

if [[ "${2:-}" == render ]]; then
    render
    exit
fi

require_wifi_ip "$backend_ip"
case "${2:-}" in
    status)
        sudo pfctl -s info
        sudo pfctl -a "$anchor" -sr
        ;;
    apply)
        main_rules="$(sudo pfctl -sr)"
        [[ "$main_rules" == *'anchor "com.apple/*"'* ]] || die "Active PF does not call com.apple/*."
        rules="$(make_temp_file)"
        trap 'cleanup_temp_file "$rules"' EXIT
        render > "$rules"
        sudo pfctl -a "$anchor" -n -f "$rules"
        if [[ ! -d "$state" ]]; then
            existing="$(sudo pfctl -a "$anchor" -sr)"
            [[ -z "$existing" ]] || die "Anchor already contains live rules. Restore the earlier demo using its original PF token first."
            original_status="$(sudo pfctl -s info)"
            ensure_backup_dir
            mkdir "$state"
            printf '%s\n' "$existing" > "$state/original.pf"
            printf '%s\n' "$original_status" > "$state/original-status.txt"
            if ! enabled="$(sudo pfctl -E 2>&1)"; then
                rm "$state/original.pf" "$state/original-status.txt"
                rmdir "$state"
                die "$enabled"
            fi
            token="$(printf '%s\n' "$enabled" | awk '/Token[[:space:]]*:/ {print $NF}')"
            [[ "$token" =~ ^[0-9]+$ ]] || die "Could not read PF reference token. Check pfctl -s References."
            printf '%s\n' "$token" > "$state/token"
        fi
        require_file "$state/token"
        sudo pfctl -a "$anchor" -f "$rules"
        sudo pfctl -a "$anchor" -sr
        ;;
    restore)
        require_file "$state/token"
        require_file "$state/original.pf"
        cat "$state/original-status.txt"
        sudo pfctl -a "$anchor" -f "$state/original.pf"
        sudo pfctl -X "$(cat "$state/token")"
        rm "$state/token" "$state/original.pf" "$state/original-status.txt"
        rmdir "$state"
        sudo pfctl -s info
        sudo pfctl -a "$anchor" -sr
        ;;
    *) die "Usage: $0 a|b render|apply|status|restore [primary|standby]" ;;
esac
