#!/usr/bin/env bash
set -euo pipefail

if (( EUID == 0 )); then
    printf 'Run this script as the desktop user.\n' >&2
    exit 1
fi
if (( $# != 1 )); then
    printf 'Usage: %s CALC_LAUNCHER_FILE\n' "$0" >&2
    exit 2
fi

launcher_dir="$HOME/.config/cairo-dock/current_theme/launchers"
backup="$HOME/.config/mylastarch-backups/cairo-launchers-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$launcher_dir" "$backup"

for duplicate in \
    02-firefox.desktop \
    03-konsole.desktop \
    04-libreoffice.desktop \
    06-thunderbird.desktop; do
    if [[ -f "$launcher_dir/$duplicate" ]]; then
        mv "$launcher_dir/$duplicate" "$backup/$duplicate"
    fi
done

install -m 0644 "$1" "$launcher_dir/04-libreoffice-calc.desktop"
printf 'Updated Cairo-Dock launchers. Backup: %s\n' "$backup"
