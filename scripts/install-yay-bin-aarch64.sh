#!/usr/bin/env bash
set -euo pipefail

if (( EUID == 0 )); then
    printf 'Build AUR packages as a regular user, not root.\n' >&2
    exit 1
fi
if [[ $(uname -m) != aarch64 ]]; then
    printf 'This installer is intended for aarch64, not %s.\n' "$(uname -m)" >&2
    exit 1
fi

for command_name in git makepkg sudo; do
    command -v "$command_name" >/dev/null || {
        printf 'Missing prerequisite: %s\n' "$command_name" >&2
        exit 1
    }
done

build_root="${XDG_CACHE_HOME:-$HOME/.cache}/mylastarch-aur-build"
repo="$build_root/yay-bin"
mkdir -p "$build_root"
if [[ -d "$repo/.git" ]]; then
    git -C "$repo" pull --ff-only
else
    git clone https://aur.archlinux.org/yay-bin.git "$repo"
fi

cd "$repo"
makepkg --printsrcinfo > .SRCINFO.reviewed
grep -qx $'\tarch = aarch64' .SRCINFO.reviewed || {
    printf 'Refusing to build: current yay-bin metadata does not support aarch64.\n' >&2
    exit 1
}

printf 'Reviewing package metadata from %s\n' "$(git rev-parse HEAD)"
makepkg --syncdeps --install --cleanbuild --clean
yay --version
