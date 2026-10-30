#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  printf 'Usage: %s PACKAGE_LIST [OUTPUT_DIRECTORY]\n' "$0" >&2
  exit 2
fi

input_file=$1
output_dir=${2:-aarch64-package-audit}

if [[ ! -r "$input_file" ]]; then
  printf 'Package list is not readable: %s\n' "$input_file" >&2
  exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
  printf 'This audit must run on an Arch-based system with pacman.\n' >&2
  exit 1
fi

mkdir -p -- "$output_dir"
package_names="$output_dir/requested.txt"
available="$output_dir/available.txt"
unavailable="$output_dir/unavailable.txt"
metadata="$output_dir/available.tsv"
installed="$output_dir/already-installed.txt"

awk '
  {
    sub(/#.*/, "")
    gsub(/^[[:space:]]+|[[:space:]]+$/, "")
    if (length($0)) print $0
  }
' "$input_file" | LC_ALL=C sort -u >"$package_names"

: >"$available"
: >"$unavailable"
: >"$installed"
printf 'package\trepository\tversion\tarchitecture\n' >"$metadata"

while IFS= read -r package_name; do
  if package_info=$(LC_ALL=C pacman -Si "$package_name" 2>/dev/null); then
    repository=$(awk -F: '$1 ~ /^[[:space:]]*Repository[[:space:]]*$/ { sub(/^[^:]*:[[:space:]]*/, ""); print; exit }' <<<"$package_info")
    version=$(awk -F: '$1 ~ /^[[:space:]]*Version[[:space:]]*$/ { sub(/^[^:]*:[[:space:]]*/, ""); print; exit }' <<<"$package_info")
    architecture=$(awk -F: '$1 ~ /^[[:space:]]*Architecture[[:space:]]*$/ { sub(/^[^:]*:[[:space:]]*/, ""); print; exit }' <<<"$package_info")
    printf '%s\n' "$package_name" >>"$available"
    printf '%s\t%s\t%s\t%s\n' \
      "$package_name" "$repository" "$version" "$architecture" >>"$metadata"
  else
    printf '%s\n' "$package_name" >>"$unavailable"
  fi

  if pacman -Q "$package_name" >/dev/null 2>&1; then
    printf '%s\n' "$package_name" >>"$installed"
  fi
done <"$package_names"

{
  printf 'audit_date=%s\n' "$(date --iso-8601=seconds)"
  if command -v hostname >/dev/null 2>&1; then
    audit_hostname=$(hostname)
  else
    audit_hostname=$(sed -n '1p' /etc/hostname 2>/dev/null || true)
  fi
  printf 'hostname=%s\n' "$audit_hostname"
  printf 'architecture=%s\n' "$(uname -m)"
  printf 'kernel=%s\n' "$(uname -r)"
  printf 'requested=%s\n' "$(wc -l <"$package_names")"
  printf 'available=%s\n' "$(wc -l <"$available")"
  printf 'unavailable=%s\n' "$(wc -l <"$unavailable")"
  printf 'already_installed=%s\n' "$(wc -l <"$installed")"
} >"$output_dir/summary.txt"

printf 'Package audit complete: %s\n' "$output_dir"
cat "$output_dir/summary.txt"
