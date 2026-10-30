#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  printf 'Run this mirror selector as root.\n' >&2
  exit 1
fi

mirrorlist=/etc/pacman.d/mirrorlist
backup="$mirrorlist.before-mylastarch-$(date +%Y%m%d-%H%M%S)"
cp -a -- "$mirrorlist" "$backup"

cat >"$mirrorlist" <<'EOF'
# MyLastArch Raspberry Pi — Arch Linux ARM recommended mirror redirect
# GeoIP directs requests to a nearby official, push-synchronized mirror.
Server = http://mirror.archlinuxarm.org/$arch/$repo
EOF

chmod 0644 "$mirrorlist"
printf 'Updated %s\nBackup: %s\n' "$mirrorlist" "$backup"
pacman -Syy
