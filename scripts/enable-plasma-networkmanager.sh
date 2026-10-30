#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    printf 'Run this network transition as root.\n' >&2
    exit 1
fi

install -d -m 0755 /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/20-mylastarch-wifi.conf <<'EOF'
[device]
wifi.backend=iwd
EOF

# NetworkManager owns addressing and exposes connections to Plasma's network
# applet. iwd remains the Wi-Fi backend; systemd-resolved remains DNS service.
systemctl disable --now systemd-networkd-wait-online.service || true
systemctl disable --now systemd-networkd.service
systemctl enable --now NetworkManager.service
systemctl reset-failed systemd-networkd-wait-online.service || true

printf 'NetworkManager is active. Plasma can now select wired and Wi-Fi networks.\n'
systemctl --no-pager --full status NetworkManager.service | sed -n '1,18p'
