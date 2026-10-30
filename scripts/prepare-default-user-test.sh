#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    printf 'Run this migration script as root.\n' >&2
    exit 1
fi
if (( $# < 1 || $# > 2 )); then
    printf 'Usage: %s ROOTFS_OVERLAY_DIRECTORY [DIAGNOSTIC_PUBLIC_KEY]\n' "$0" >&2
    exit 2
fi

overlay=$1
diagnostic_key=${2:-}
target_user=default
target_home=/home/default

if getent passwd "$target_user" >/dev/null; then
    printf 'Refusing to overwrite existing user: %s\n' "$target_user" >&2
    exit 1
fi

install -d -m 0755 /usr/local/bin /usr/local/share/mylastarch
install -m 0755 "$overlay/usr/local/bin/mylastarch-first-login" /usr/local/bin/
install -m 0644 "$overlay/usr/local/share/mylastarch/plasma-panel-mylastarch.js" \
    /usr/local/share/mylastarch/

# Refresh the portable skeleton without copying caches, credentials, or live
# Plasma session state from the current alarm account.
cp -r --no-preserve=ownership "$overlay/etc/skel/." /etc/skel/
chown -R root:root /etc/skel

useradd --create-home --groups wheel --shell /bin/bash "$target_user"
printf 'default:default\nroot:root\n' | chpasswd
chown -R "$target_user:$target_user" "$target_home"

if [[ -n "$diagnostic_key" && -f "$diagnostic_key" ]]; then
    install -d -m 0700 -o "$target_user" -g "$target_user" "$target_home/.ssh"
    install -m 0600 -o "$target_user" -g "$target_user" \
        "$diagnostic_key" "$target_home/.ssh/authorized_keys"
fi

printf 'Created the default test account; alarm remains available.\n'
printf 'Log in once as default to run the portable first-login setup.\n'
