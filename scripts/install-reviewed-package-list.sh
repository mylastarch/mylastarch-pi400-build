#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  printf 'Run this package installer as root.\n' >&2
  exit 1
fi

if [[ $# -ne 1 || ! -r $1 ]]; then
  printf 'Usage: %s PACKAGE_LIST\n' "$0" >&2
  exit 2
fi

if [[ $(uname -m) != aarch64 ]]; then
  printf 'Refusing to install: expected aarch64, found %s.\n' "$(uname -m)" >&2
  exit 1
fi

package_list=$1
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
    printf 'Unavailable package; nothing was installed: %s\n' "$package_name" >&2
    exit 1
  fi
done

printf 'Installing %d reviewed packages:\n' "${#packages[@]}"
printf '  %s\n' "${packages[@]}"
pacman -Syu --needed "${packages[@]}"
printf 'Reviewed package installation completed.\n'

