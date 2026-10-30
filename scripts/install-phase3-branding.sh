#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  printf 'Run this branding installer as root.\n' >&2
  exit 1
fi

if [[ $# -lt 1 || $# -gt 2 ]]; then
  printf 'Usage: %s ROOTFS_OVERLAY_DIRECTORY [TARGET_USER]\n' "$0" >&2
  exit 2
fi

overlay=$1
target_user=${2:-alarm}
wallpaper_source="$overlay/usr/share/wallpapers/MyLastArch"
login_wallpaper_source="$overlay/var/lib/plasmalogin/wallpapers/01.jpg"
login_config_source="$overlay/etc/plasmalogin.conf"
variety_source="$overlay/etc/skel/.config/variety"
autostart_source="$overlay/etc/skel/.config/autostart/variety.desktop"
sync_helper_source="$overlay/usr/local/libexec/plm-wallpaper-sync"
sync_service_source="$overlay/etc/systemd/system/plm-wallpaper-sync.service"
sync_timer_source="$overlay/etc/systemd/system/plm-wallpaper-sync.timer"

for required_path in \
  "$wallpaper_source/metadata.desktop" \
  "$wallpaper_source/contents/config" \
  "$wallpaper_source/contents/images/mylastarch.png" \
  "$login_wallpaper_source" \
  "$login_config_source" \
  "$variety_source/variety.conf" \
  "$variety_source/scripts/set_wallpaper" \
  "$variety_source/scripts/get_wallpaper" \
  "$autostart_source" \
  "$sync_helper_source" \
  "$sync_service_source" \
  "$sync_timer_source"; do
  if [[ ! -f "$required_path" ]]; then
    printf 'Missing branding input: %s\n' "$required_path" >&2
    exit 1
  fi
done

if ! getent passwd plasmalogin >/dev/null; then
  printf 'The plasmalogin system account does not exist.\n' >&2
  exit 1
fi

target_home=$(getent passwd "$target_user" | awk -F: '{ print $6 }')
if [[ -z "$target_home" || ! -d "$target_home" ]]; then
  printf 'Target user or home directory is unavailable: %s\n' "$target_user" >&2
  exit 1
fi

pacman -S --needed variety libayatana-appindicator

install -d -m 0755 /usr/share/wallpapers/MyLastArch/contents/images
install -m 0644 "$wallpaper_source/metadata.desktop" \
  /usr/share/wallpapers/MyLastArch/metadata.desktop
install -m 0644 "$wallpaper_source/contents/config" \
  /usr/share/wallpapers/MyLastArch/contents/config
install -m 0644 "$wallpaper_source/contents/images/mylastarch.png" \
  /usr/share/wallpapers/MyLastArch/contents/images/mylastarch.png

install -d -m 0750 -o plasmalogin -g plasmalogin \
  /var/lib/plasmalogin/wallpapers
install -m 0644 -o plasmalogin -g plasmalogin \
  "$login_wallpaper_source" /var/lib/plasmalogin/wallpapers/01.jpg
install -m 0644 "$login_config_source" /etc/plasmalogin.conf

backup_suffix=$(date +%Y%m%d-%H%M%S)
if [[ -e "$target_home/.config/variety" ]]; then
  mv -- "$target_home/.config/variety" \
    "$target_home/.config/variety.before-mylastarch-$backup_suffix"
fi
install -d -m 0755 -o "$target_user" -g "$target_user" \
  "$target_home/.config" "$target_home/.config/autostart"
cp -r --no-preserve=ownership "$variety_source" "$target_home/.config/variety"
install -m 0644 -o "$target_user" -g "$target_user" \
  "$autostart_source" "$target_home/.config/autostart/variety.desktop"
chown -R "$target_user:$target_user" "$target_home/.config/variety"
chmod 0755 "$target_home/.config/variety/scripts/set_wallpaper" \
  "$target_home/.config/variety/scripts/get_wallpaper" \
  "$target_home/.config/variety/scripts/set_lock_screen"

install -d -m 0755 /usr/local/libexec
install -m 0755 "$sync_helper_source" /usr/local/libexec/plm-wallpaper-sync
install -m 0644 "$sync_service_source" \
  /etc/systemd/system/plm-wallpaper-sync.service
install -m 0644 "$sync_timer_source" \
  /etc/systemd/system/plm-wallpaper-sync.timer
systemctl daemon-reload
systemctl enable plm-wallpaper-sync.service
systemctl enable --now plm-wallpaper-sync.timer

printf 'Installed the mylastarch wallpapers and Variety configuration.\n'
printf 'Plasma Login Manager will load its wallpaper at its next start.\n'
