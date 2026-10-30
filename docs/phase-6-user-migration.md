# Phase 6: final default-user migration

The live test image continues using the upstream `alarm` account until desktop
validation and image automation are complete. Removing it earlier would break
the current SSH diagnostic path and make regressions harder to recover from.

## Intended development-image credentials

- User: `default`
- User password: `default`
- Root password: `root`
- Administrative group: `wheel`

These are public development credentials and are unsafe on an untrusted
network. The final image must display a first-login warning and documentation
must instruct users to change both passwords immediately. Root SSH login should
remain disabled.

## Migration sequence

1. Capture the final portable user settings into `/etc/skel`; exclude caches,
   machine IDs, session state, secrets, downloaded credentials, and SSH keys.
2. Create `default`, its home directory, and `wheel` membership.
3. Seed `/home/default` from the finalized skeleton with correct ownership.
4. Set the requested development passwords.
5. Temporarily authorize the project diagnostic SSH key for `default`.
6. Reboot and validate login manager authentication, Plasma Wayland, panel,
   Global Menu, Window List, Cairo-Dock, Variety, XScreenSaver, audio,
   Bluetooth, SMB, sudo, Yay, update notifier, and root escalation.
7. Keep `alarm` as a fallback until every check passes.
8. Remove `alarm` and its home only after explicit final confirmation, then
   verify no files elsewhere remain owned by its UID.

The final image builder should create `default` directly so newly flashed cards
never expose the upstream `alarm` account.

The test migration uses a one-time Plasma autostart helper rather than copying
the live `alarm` session database. This applies portable appearance settings
and constructs the curated panel after Plasma is ready, then records a marker
so it does not reset later user customizations.

The `default` validation passed for Plasma Wayland, the curated top panel,
Papirus, Num Lock off, `archsimpleblue`, Cairo-Dock, XScreenSaver, the update
notifier, SMB `.local` access, Wi-Fi, Yay, and system health. Two remaining
UID-1000 system files (`mylastarch-grow-root.service` and its helper) must be
returned to root ownership before the upstream `alarm` account is removed.

The cleanup completed successfully. The `alarm` account and `/home/alarm` are
absent, no paths under `/etc`, `/usr`, or `/var` remain owned by UID 1000, and
the grow-root service/helper are root-owned with modes 0644/0755. The `default`
desktop session, Wi-Fi, Cairo-Dock, XScreenSaver, update notifier, and systemd
health remained intact. The test account retains UID 1001 because it was
created alongside `alarm`; a newly built image will create `default` directly
as the first regular account (UID 1000).
