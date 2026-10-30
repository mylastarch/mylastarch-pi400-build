#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    printf 'Run this cleanup script as root.\n' >&2
    exit 1
fi

target_user=alarm
target_uid=$(id -u "$target_user")
[[ $target_uid == 1000 ]] || {
    printf 'Refusing cleanup: alarm has unexpected UID %s.\n' "$target_uid" >&2
    exit 1
}
getent passwd default >/dev/null || {
    printf 'Refusing cleanup: the validated default account is missing.\n' >&2
    exit 1
}

# Repair the only UID-1000 system paths found by final validation.
chown root:root \
    /etc/systemd/system/mylastarch-grow-root.service \
    /usr/local/sbin/mylastarch-grow-root
chmod 0644 /etc/systemd/system/mylastarch-grow-root.service
chmod 0755 /usr/local/sbin/mylastarch-grow-root

remaining=$(find /etc /usr /var -xdev -uid "$target_uid" -print 2>/dev/null)
if [[ -n "$remaining" ]]; then
    printf 'Refusing to remove alarm; UID %s still owns system paths:\n%s\n' \
        "$target_uid" "$remaining" >&2
    exit 1
fi

if loginctl user-status "$target_user" >/dev/null 2>&1; then
    printf 'Refusing to remove alarm while it has an active user session.\n' >&2
    exit 1
fi

userdel --remove "$target_user"
printf 'Removed the upstream alarm account and home directory.\n'
