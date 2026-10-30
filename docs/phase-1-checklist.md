# Phase 1: minimal Pi 400 image

## Build inputs

- [x] Define signature and checksum verification for the Arch Linux ARM
      Raspberry Pi AArch64 rootfs download.
- [x] Define initial image geometry: 8 GiB image, 1 GiB FAT32 boot partition,
      ext4 root, targeting a 64 GB card.
- [x] Create a FAT32 `/boot` partition and ext4 `/` partition.
- [x] Extract the root filesystem while preserving ownership and permissions.
- [ ] Install/verify the packages in `base.txt` and `hardware-pi400.txt`.
- [x] Generate `fstab` using stable filesystem labels.
- [ ] Configure hostname, locale, timezone, keymap, networking, and SSH.
- [ ] Replace the upstream `alarm` account with the final `default` development
  account after desktop validation; follow `phase-6-user-migration.md`.
- [x] Add a one-time service that safely grows partition 2 and ext4 to fill the
      destination card, then disables itself.
- [ ] Make image customization work under AArch64 emulation or on the Pi.
- [x] Unmount cleanly and produce checksums.

## Hardware acceptance test

- [x] Pi firmware loads the AArch64 kernel and reaches a console.
- [x] Root filesystem mounts read-write without repair errors.
- [x] Root partition expands to the 64 GB card's actual usable capacity once.
- [x] Ethernet obtains an address.
- [x] Wi-Fi associates, receives DHCP configuration, and reconnects after
      reboot with Ethernet disconnected.
- [x] USB keyboard works.
- [ ] USB storage works.
- [x] HDMI output works at a usable resolution.
- [x] System clock and time synchronization work.
- [x] `pacman -Syu` completes and the updated system reboots.
- [x] No failed systemd units remain unexplained.
