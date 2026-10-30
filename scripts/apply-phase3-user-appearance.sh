#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  printf 'Run this appearance script as the desktop user, not root.\n' >&2
  exit 1
fi

if ! command -v kwriteconfig6 >/dev/null 2>&1; then
  printf 'kwriteconfig6 is required.\n' >&2
  exit 1
fi

if [[ ! -d /usr/share/icons/Papirus ]]; then
  printf 'Papirus icon theme is not installed.\n' >&2
  exit 1
fi

if [[ ! -d /usr/share/icons/Vimix-cursors ]]; then
  printf 'Vimix cursor theme is not installed.\n' >&2
  exit 1
fi

backup_dir="$HOME/.config/mylastarch-backups/appearance-$(date +%Y%m%d-%H%M%S)"
mkdir -p -- "$backup_dir"
for config_file in kdeglobals kcminputrc; do
  [[ -f "$HOME/.config/$config_file" ]] && \
    cp -a -- "$HOME/.config/$config_file" "$backup_dir/"
done

kwriteconfig6 --file kdeglobals --group Icons --key Theme Papirus
kwriteconfig6 --file kdeglobals --group General --key AccentColor '80,160,113'
kwriteconfig6 --file kdeglobals --group General --key accentColorFromWallpaper true
kwriteconfig6 --file kdeglobals --group General --key font \
  'Noto Sans,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1'
kwriteconfig6 --file kdeglobals --group General --key menuFont \
  'Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1'
kwriteconfig6 --file kdeglobals --group KDE --key ShowDeleteCommand true
kwriteconfig6 --file kdeglobals --group 'KFileDialog Settings' \
  --key 'Show hidden files' true
kwriteconfig6 --file kdeglobals --group 'KFileDialog Settings' \
  --key 'Sort directories first' true
kwriteconfig6 --file kcminputrc --group Keyboard --key NumLock 0
kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme Vimix-cursors
kwriteconfig6 --file kcminputrc --group Mouse --key cursorSize 24

printf 'Applied portable mylastarch appearance settings.\n'
printf 'Backup: %s\n' "$backup_dir"
printf 'Log out and back in to apply icons, fonts, and cursor everywhere.\n'

