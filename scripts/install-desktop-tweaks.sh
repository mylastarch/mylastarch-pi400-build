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
[[ -n "$target_home" && -d "$target_home" ]] || {
    printf 'Target user is unavailable: %s\n' "$target_user" >&2
    exit 1
}

pacman -S --needed xscreensaver

install -d -m 0755 /usr/local/bin /usr/share/kio/servicemenus /usr/share/applications
install -m 0755 "$overlay/usr/local/bin/mylastarch-dolphin-action" /usr/local/bin/
install -m 0755 "$overlay/usr/local/bin/mylastarch-xscreensaver-start" /usr/local/bin/
install -m 0644 "$overlay/usr/share/kio/servicemenus/"mylastarch-*.desktop /usr/share/kio/servicemenus/
install -m 0644 "$overlay/usr/share/applications/mylastarch-xscreensaver-settings.desktop" /usr/share/applications/

backup="$target_home/.config/mylastarch-backups/desktop-tweaks-$(date +%Y%m%d-%H%M%S)"
install -d -m 0755 -o "$target_user" -g "$target_user" "$backup"
for path in \
    "$target_home/.xscreensaver" \
    "$target_home/.config/autostart/xscreensaver.desktop" \
    "$target_home/.config/kservicemenurc" \
    "$target_home/.local/share/kxmlgui5/dolphin/dolphinui.rc"; do
    if [[ -f "$path" ]]; then
        install -m 0644 -o "$target_user" -g "$target_user" "$path" "$backup/$(basename "$path")"
    fi
done

install -d -m 0755 -o "$target_user" -g "$target_user" \
    "$target_home/.config/autostart" \
    "$target_home/.local/share/kxmlgui5/dolphin"
install -m 0644 -o "$target_user" -g "$target_user" \
    "$overlay/etc/skel/.xscreensaver" "$target_home/.xscreensaver"
install -m 0644 -o "$target_user" -g "$target_user" \
    "$overlay/etc/skel/.config/autostart/xscreensaver.desktop" \
    "$target_home/.config/autostart/xscreensaver.desktop"
install -m 0644 -o "$target_user" -g "$target_user" \
    "$overlay/etc/skel/.config/kservicemenurc" "$target_home/.config/kservicemenurc"
install -m 0644 -o "$target_user" -g "$target_user" \
    "$overlay/etc/skel/.local/share/kxmlgui5/dolphin/dolphinui.rc" \
    "$target_home/.local/share/kxmlgui5/dolphin/dolphinui.rc"

printf 'Installed Dolphin actions and XScreenSaver defaults.\n'
printf 'Backup directory: %s\n' "$backup"
printf 'Log out and back in to start XScreenSaver automatically.\n'
