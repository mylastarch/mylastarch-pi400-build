#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    printf 'Run this script as root.\n' >&2
    exit 1
fi

install -d -m 0755 /etc/systemd/system/systemd-networkd-wait-online.service.d
install -m 0644 "${1:-/tmp/wait-for-only-one-interface.conf}" \
    /etc/systemd/system/systemd-networkd-wait-online.service.d/wait-for-only-one-interface.conf

systemctl daemon-reload
systemctl reset-failed systemd-networkd-wait-online.service
systemctl restart systemd-networkd-wait-online.service

systemctl is-active systemd-networkd-wait-online.service
systemctl status systemd-networkd-wait-online.service --no-pager
