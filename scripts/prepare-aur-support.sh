#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    printf 'Run this preparation script as root.\n' >&2
    exit 1
fi

pacman -S --needed base-devel git sudo

sudoers_file=/etc/sudoers.d/10-wheel
printf '%%wheel ALL=(ALL:ALL) ALL\n' > "$sudoers_file"
chmod 0440 "$sudoers_file"
visudo -cf /etc/sudoers

printf 'AUR prerequisites installed and wheel sudo access enabled.\n'
