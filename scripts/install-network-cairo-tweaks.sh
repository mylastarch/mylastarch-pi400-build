#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    printf 'Run this installer as root.\n' >&2
    exit 1
fi
if (( $# < 1 || $# > 2 )); then
    printf 'Usage: %s ROOTFS_OVERLAY_DIRECTORY [TARGET_USER]\n' "$0" >&2
    exit 2
fi

overlay=$1
target_user=${2:-alarm}
target_home=$(getent passwd "$target_user" | awk -F: '{print $6}')
[[ -n "$target_home" && -d "$target_home" ]] || exit 1

install -d -m 0755 /usr/local/bin
install -m 0755 "$overlay/usr/local/bin/mylastarch-cairo-dock-start" /usr/local/bin/

install -d -m 0755 /etc/samba
install -m 0644 "$overlay/etc/samba/smb.conf" /etc/samba/smb.conf
if ! grep -qE '^hosts:.*mdns4_minimal' /etc/nsswitch.conf; then
    sed -i -E \
        's/^(hosts:[[:space:]]+mymachines)([[:space:]])/\1 mdns4_minimal [NOTFOUND=return]\2/' \
        /etc/nsswitch.conf
fi

backup="$target_home/.config/mylastarch-backups/cairo-$(date +%Y%m%d-%H%M%S)"
install -d -m 0755 -o "$target_user" -g "$target_user" "$backup"
if [[ -d "$target_home/.config/cairo-dock" ]]; then
    cp -a "$target_home/.config/cairo-dock" "$backup/"
fi

install -d -m 0755 -o "$target_user" -g "$target_user" \
    "$target_home/.config/autostart" \
    "$target_home/.config/cairo-dock/current_theme/launchers"
for obsolete_launcher in \
    02-firefox.desktop \
    03-konsole.desktop \
    04-libreoffice.desktop \
    06-thunderbird.desktop; do
    obsolete_path="$target_home/.config/cairo-dock/current_theme/launchers/$obsolete_launcher"
    if [[ -f "$obsolete_path" ]]; then
        mv "$obsolete_path" "$backup/$obsolete_launcher"
    fi
done
install -m 0644 -o "$target_user" -g "$target_user" \
    "$overlay/etc/skel/.config/autostart/cairo-dock.desktop" \
    "$target_home/.config/autostart/cairo-dock.desktop"
install -m 0644 -o "$target_user" -g "$target_user" \
    "$overlay/etc/skel/.config/cairo-dock/current_theme/launchers/"*.desktop \
    "$target_home/.config/cairo-dock/current_theme/launchers/"
chown -R "$target_user:$target_user" "$target_home/.config/cairo-dock"

if [[ -d "$overlay/etc/skel/.local/share/plasma/look-and-feel/archsimpleblue" ]]; then
    if [[ -f "$target_home/.config/ksplashrc" ]]; then
        install -m 0644 -o "$target_user" -g "$target_user" \
            "$target_home/.config/ksplashrc" "$backup/ksplashrc"
    fi
    install -d -m 0755 -o "$target_user" -g "$target_user" \
        "$target_home/.local/share/plasma/look-and-feel"
    if [[ -d "$target_home/.local/share/plasma/look-and-feel/archsimpleblue" ]]; then
        mv "$target_home/.local/share/plasma/look-and-feel/archsimpleblue" \
            "$backup/archsimpleblue"
    fi
    cp -r --no-preserve=ownership \
        "$overlay/etc/skel/.local/share/plasma/look-and-feel/archsimpleblue" \
        "$target_home/.local/share/plasma/look-and-feel/archsimpleblue"
    chown -R "$target_user:$target_user" \
        "$target_home/.local/share/plasma/look-and-feel/archsimpleblue"
    install -m 0644 -o "$target_user" -g "$target_user" \
        "$overlay/etc/skel/.config/ksplashrc" "$target_home/.config/ksplashrc"
fi

printf 'Installed SMB mDNS resolution, Cairo-Dock, and the Plasma splash.\n'
printf 'Cairo-Dock backup: %s\n' "$backup"
