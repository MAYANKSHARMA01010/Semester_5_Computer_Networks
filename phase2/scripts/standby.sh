#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/helpers/env.sh"

render() {
    sed -e "s/@APP_DOMAIN@/$APP_DOMAIN/g" -e "s/@API_DOMAIN@/$API_DOMAIN/g" \
        -e "s/@HTTPS_PORT@/$NGINX_HTTPS_PORT/g" -e "s/@A_PORT@/$BACKEND_A_PORT/g" \
        -e "s/@B_IP@/$MAC_IP_4_BACKEND_B/g" -e "s/@B_PORT@/$BACKEND_B_PORT/g" \
        "$PHASE2/config/nginx-standby.conf.in"
}

if [[ "${1:-}" == render ]]; then
    render
    exit
fi

require_wifi_ip "$MAC_IP_3_BACKEND_A"
require_command nginx
standby_dir="${CN_STANDBY_DIR:-$HOME/.cn-phase2-standby}"
case "${1:-}" in
    start)
        mkdir -p "$standby_dir"
        [[ ! -s "$standby_dir/nginx.pid" ]] || die "Standby PID file exists. Check status before starting."
        if [[ ! -e "$standby_dir/team1.crt" && ! -e "$standby_dir/team1.key" ]]; then
            (
                cd "$standby_dir" || exit 1
                openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                    -subj "/CN=$APP_DOMAIN" -keyout team1.key -out team1.crt \
                    -config <(printf '[req]\ndistinguished_name=dn\nx509_extensions=leaf\n[dn]\n[leaf]\nsubjectAltName=DNS:%s,DNS:%s\n' "$APP_DOMAIN" "$API_DOMAIN")
            )
        fi
        require_file "$standby_dir/team1.crt"
        require_file "$standby_dir/team1.key"
        render > "$standby_dir/nginx.conf"
        nginx -p "$standby_dir/" -c nginx.conf -t
        nginx -p "$standby_dir/" -c nginx.conf
        printf 'Public certificate: %s/team1.crt\n' "$standby_dir"
        ;;
    stop)
        nginx -p "$standby_dir/" -c nginx.conf -s quit
        ;;
    *) die "Usage: $0 render|start|stop" ;;
esac
