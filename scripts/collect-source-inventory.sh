#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_dir=$(cd -- "$script_dir/.." && pwd)
output_dir=${1:-"$project_dir/inventory/source"}

if [[ ! -r /etc/os-release ]]; then
  printf 'Error: /etc/os-release is not readable.\n' >&2
  exit 1
fi

mkdir -p -- "$output_dir"

capture() {
  local output_file=$1
  shift
  if command -v "$1" >/dev/null 2>&1; then
    "$@" >"$output_dir/$output_file" 2>"$output_dir/$output_file.stderr" || true
    if [[ ! -s "$output_dir/$output_file.stderr" ]]; then
      rm -f -- "$output_dir/$output_file.stderr"
    fi
  fi
}

cp -- /etc/os-release "$output_dir/os-release"
uname -a >"$output_dir/uname.txt"
uname -m >"$output_dir/architecture.txt"

if command -v pacman >/dev/null 2>&1; then
  pacman -Qqen >"$output_dir/packages-repository-explicit.txt"
  pacman -Qqem >"$output_dir/packages-foreign-explicit.txt"
  pacman -Qqe >"$output_dir/packages-all-explicit.txt"
  pacman -Q >"$output_dir/packages-installed-with-versions.txt"
fi

capture enabled-system-services.txt systemctl list-unit-files --state=enabled --no-legend --no-pager
capture enabled-user-services.txt systemctl --user list-unit-files --state=enabled --no-legend --no-pager
capture failed-system-services.txt systemctl --failed --no-legend --no-pager
capture block-devices.txt lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
capture pci-devices.txt lspci -nn
capture usb-devices.txt lsusb
capture desktop-session.txt env

# Keep only variable names useful for identifying the desktop/session. Values
# such as tokens, agent sockets, and arbitrary environment secrets are omitted.
if [[ -f "$output_dir/desktop-session.txt" ]]; then
  sed -n -E '/^(DESKTOP_SESSION|DISPLAY|GDMSESSION|LANG|LC_[A-Z_]+|SHELL|WAYLAND_DISPLAY|XDG_CURRENT_DESKTOP|XDG_SESSION_DESKTOP|XDG_SESSION_TYPE)=/p' \
    "$output_dir/desktop-session.txt" >"$output_dir/desktop-environment.txt"
  rm -f -- "$output_dir/desktop-session.txt"
fi

{
  printf '# Existing configuration paths (contents are not copied)\n'
  for path in \
    /etc/mkinitcpio.conf \
    /etc/pacman.conf \
    /etc/systemd/network \
    /etc/NetworkManager \
    /etc/X11 \
    /etc/environment \
    /etc/locale.conf \
    /etc/vconsole.conf; do
    [[ -e "$path" ]] && printf '%s\n' "$path"
  done
} >"$output_dir/config-paths.txt"

printf 'Inventory written to %s\n' "$output_dir"
printf 'Review it for personal information before sharing or committing.\n'

