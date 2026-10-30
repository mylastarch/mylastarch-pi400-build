#!/usr/bin/env bash
set -euo pipefail

if (( EUID == 0 )); then
    printf 'Run this panel script as the desktop user.\n' >&2
    exit 1
fi
if (( $# != 1 )); then
    printf 'Usage: %s PANEL_JAVASCRIPT\n' "$0" >&2
    exit 2
fi

panel_script=$1
[[ -f "$panel_script" ]] || { printf 'Missing: %s\n' "$panel_script" >&2; exit 1; }
command -v qdbus6 >/dev/null

backup_dir="$HOME/.config/mylastarch-backups/panel-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"
if [[ -f "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" ]]; then
    cp -a "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" "$backup_dir/"
fi

qdbus6 org.kde.plasmashell /PlasmaShell \
    org.kde.PlasmaShell.evaluateScript "$(< "$panel_script")"
printf 'Applied the MyLastArch top panel. Backup: %s\n' "$backup_dir"
