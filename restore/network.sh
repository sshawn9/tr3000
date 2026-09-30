#!/usr/bin/env bash
set -euo pipefail

CONNECTION_NAME=${TR3000_CONNECTION:-tr3000}
INTERFACE_NAME=${TR3000_INTERFACE:-enp2s0}
LAN_ADDRESS=10.0.0.2/24
TFTP_ADDRESS=192.168.1.254/24
ROUTER_ADDRESS=10.0.0.1

create_connection() {
    local connections
    connections=$(nmcli --escape no -g NAME connection show) || return
    if grep -Fxq -- "$CONNECTION_NAME" <<< "$connections"; then
        printf 'Connection "%s" already exists. Keeping its settings; use status to inspect it.\n' "$CONNECTION_NAME"
        return 0
    fi

    nmcli connection add \
        type ethernet ifname "$INTERFACE_NAME" con-name "$CONNECTION_NAME" \
        connection.autoconnect no connection.autoconnect-priority 0 \
        ipv4.method manual ipv4.addresses "$LAN_ADDRESS,$TFTP_ADDRESS" \
        ipv4.gateway "$ROUTER_ADDRESS" ipv4.dns "$ROUTER_ADDRESS" \
        ipv4.never-default no ipv4.may-fail no \
        ipv6.method auto ipv6.may-fail yes
}

up_connection() {
    nmcli connection modify id "$CONNECTION_NAME" \
        connection.autoconnect yes connection.autoconnect-priority 100 || return
    nmcli connection up id "$CONNECTION_NAME" ifname "$INTERFACE_NAME"
}

down_connection() {
    nmcli connection modify id "$CONNECTION_NAME" \
        connection.autoconnect no connection.autoconnect-priority 0 || return
    nmcli connection down id "$CONNECTION_NAME"
}

delete_connection() {
    nmcli connection delete id "$CONNECTION_NAME"
}

show_connection() {
    nmcli -f connection.id,connection.interface-name,connection.autoconnect,connection.autoconnect-priority,ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns,ipv4.never-default,ipv6.method \
        connection show id "$CONNECTION_NAME" || return
    nmcli -f GENERAL.STATE,GENERAL.CONNECTION,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS \
        device show "$INTERFACE_NAME"
}

usage() {
    cat <<'EOF'
Usage: network.sh <command>
  create  Create the connection profile unless it already exists.
  up      Enable autoconnect (priority 100) and activate the connection.
  down    Disable autoconnect (priority 0) and disconnect.
  delete  Delete the saved connection profile.
  status  Show the saved configuration and current interface status.
  help    Show this help.

Defaults: connection tr3000, interface enp2s0.
Override with TR3000_CONNECTION and TR3000_INTERFACE.
Commands that change connections may require sudo.
Run up after create to activate the connection.
EOF
}

main() {
    local action=${1:-help}
    if (( $# > 1 )); then
        usage >&2
        return 2
    fi

    case "$action" in
        create) create_connection ;;
        up) up_connection ;;
        down) down_connection ;;
        delete) delete_connection ;;
        status) show_connection ;;
        help|-h|--help) usage ;;
        *) printf 'Unknown command: %s\n' "$action" >&2; usage >&2; return 2 ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
