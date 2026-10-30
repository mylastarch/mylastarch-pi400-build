#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    printf 'Run this image patcher as root.\n' >&2
    exit 1
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_dir=$(cd -- "$script_dir/.." && pwd)
image=${1:-"$project_dir/output/mylastarch-pi400-2026.11.01-aarch64.img"}
overlay="$project_dir/config/rootfs"
work_dir=''
loop_device=''
root_mount=''

cleanup() {
    set +e
    if [[ -n "$root_mount" ]] && mountpoint -q "$root_mount"; then
        umount "$root_mount"
    fi
    if [[ -n "$loop_device" ]]; then
        losetup -d "$loop_device" 2>/dev/null || true
    fi
    if [[ -n "$work_dir" && -d "$work_dir" ]] && ! mountpoint -q "$root_mount"; then
        rm -rf -- "$work_dir"
    fi
}
trap cleanup EXIT

[[ -f "$image" ]] || { printf 'Image not found: %s\n' "$image" >&2; exit 1; }
for required in \
    "$overlay/usr/local/bin/mylastarch-cairo-dock-start" \
    "$overlay/etc/skel/.config/cairo-dock/current_theme/cairo-dock.conf" \
    "$overlay/etc/skel/.config/cairo-dock/.cairo-dock" \
    "$overlay/etc/skel/.config/cairo-dock/.help" \
    "$overlay/etc/skel/.config/variety/.firstrun" \
    "$overlay/etc/skel/.config/variety/.version" \
    "$overlay/etc/skel/.config/kdeglobals" \
    "$overlay/etc/skel/.config/kwinrc"; do
    [[ -f "$required" ]] || { printf 'Missing patch input: %s\n' "$required" >&2; exit 1; }
done

[[ -z $(losetup -j "$image") ]] || {
    printf 'Image already has a loop association: %s\n' "$image" >&2
    exit 1
}

rm -f -- "$image.sha256"
work_dir=$(mktemp -d --tmpdir mylastarch-first-run-patch.XXXXXXXX)
root_mount="$work_dir/root"
mkdir -p "$root_mount"
loop_device=$(losetup --find --show --partscan "$image")
mount "${loop_device}p2" "$root_mount"

install -m 0755 "$overlay/usr/local/bin/mylastarch-cairo-dock-start" \
    "$root_mount/usr/local/bin/mylastarch-cairo-dock-start"

rm -rf -- "$root_mount/etc/skel/.config/cairo-dock"
install -d -m 0755 "$root_mount/etc/skel/.config"
cp -a -- "$overlay/etc/skel/.config/cairo-dock" \
    "$root_mount/etc/skel/.config/cairo-dock"
chown -R root:root "$root_mount/etc/skel/.config/cairo-dock"
install -m 0644 "$overlay/etc/skel/.config/variety/.firstrun" \
    "$root_mount/etc/skel/.config/variety/.firstrun"
install -m 0644 "$overlay/etc/skel/.config/variety/.version" \
    "$root_mount/etc/skel/.config/variety/.version"
install -m 0644 "$overlay/etc/skel/.config/kdeglobals" \
    "$root_mount/etc/skel/.config/kdeglobals"
install -m 0644 "$overlay/etc/skel/.config/kwinrc" \
    "$root_mount/etc/skel/.config/kwinrc"

# The directly flashable image already contains its default user. Mirror the
# corrected skeleton into that existing home as well as future user homes.
default_home="$root_mount/home/default"
[[ -d "$default_home" ]] || { printf 'Default user home is missing.\n' >&2; exit 1; }
default_uid=$(stat -c %u "$default_home")
default_gid=$(stat -c %g "$default_home")
rm -rf -- "$default_home/.config/cairo-dock"
install -d -m 0755 -o "$default_uid" -g "$default_gid" "$default_home/.config"
cp -a -- "$overlay/etc/skel/.config/cairo-dock" "$default_home/.config/cairo-dock"
chown -R "$default_uid:$default_gid" "$default_home/.config/cairo-dock"
install -m 0644 -o "$default_uid" -g "$default_gid" \
    "$overlay/etc/skel/.config/variety/.firstrun" \
    "$default_home/.config/variety/.firstrun"
install -m 0644 -o "$default_uid" -g "$default_gid" \
    "$overlay/etc/skel/.config/variety/.version" \
    "$default_home/.config/variety/.version"
install -m 0644 -o "$default_uid" -g "$default_gid" \
    "$overlay/etc/skel/.config/kdeglobals" \
    "$default_home/.config/kdeglobals"
install -m 0644 -o "$default_uid" -g "$default_gid" \
    "$overlay/etc/skel/.config/kwinrc" \
    "$default_home/.config/kwinrc"

sync
umount "$root_mount"
losetup -d "$loop_device"
loop_device=''
sync
sha256sum "$image" > "$image.sha256"
printf 'Patched image and created checksum:\n'
cat "$image.sha256"
