#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
default_list="$script_dir/../package-lists/desktop-phase1-candidates.txt"
package_list=${1:-$default_list}

if [[ $EUID -ne 0 ]]; then
  printf 'Run this installer as root.\n' >&2
  exit 1
fi

if [[ $(uname -m) != aarch64 ]]; then
  printf 'Refusing to install: expected aarch64, found %s.\n' "$(uname -m)" >&2
  exit 1
fi

if [[ ! -r "$package_list" ]]; then
  printf 'Package list is not readable: %s\n' "$package_list" >&2
  exit 1
fi

mapfile -t packages < <(
  awk '
    {
      sub(/#.*/, "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      if (length($0)) print $0
    }
  ' "$package_list" | LC_ALL=C sort -u
)

if (( ${#packages[@]} == 0 )); then
  printf 'No packages found in %s\n' "$package_list" >&2
  exit 1
fi

for package_name in "${packages[@]}"; do
  if ! pacman -Si "$package_name" >/dev/null 2>&1; then
    printf 'Package is unavailable; nothing was installed: %s\n' "$package_name" >&2
    exit 1
  fi
done

printf 'Installing %d reviewed desktop packages and their dependencies.\n' "${#packages[@]}"
pacman -Syu --needed "${packages[@]}"

systemctl enable plasmalogin.service
systemctl enable bluetooth.service
systemctl set-default graphical.target

printf '\nDesktop installation complete; the system has not been rebooted.\n'
printf 'Network services after installation:\n'
systemctl is-active iwd.service systemd-networkd.service || true
printf '\nEnabled display manager:\n'
systemctl is-enabled plasmalogin.service

