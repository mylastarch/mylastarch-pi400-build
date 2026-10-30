# Source profile audit

Source inspected: `../dccwebsite/archiso`

## What is reusable

- Most desktop/application package intent, subject to AArch64 availability.
- The majority of `airootfs/` branding, desktop defaults, wallpapers, helper
  scripts, polkit rules, and service configuration.
- Distribution identity and Calamares launchers.
- General PipeWire, Bluetooth, printing, networking, and KDE configuration.

## What must be replaced or reviewed

- `packages.x86_64` and all desktop-specific `*.x86_64` manifests.
- `linux`, `linux-headers`, `amd-ucode`, and `intel-ucode`.
- BIOS Syslinux and x86 UEFI/systemd-boot entries.
- `memtest86+`, `memtest86+-efi`, and `edk2-shell` assumptions.
- VirtualBox, VMware, Hyper-V, x86 video, and laptop/PC hardware packages.
- `profiledef.sh` uses `buildmodes=('iso')` and x86-specific SquashFS BCJ
  options. The Pi deliverable should normally be a bootable disk image.
- Chaotic-AUR and binary/AUR packages must be checked individually for
  AArch64 builds; package names alone do not establish compatibility.
- Calamares partitioning and bootloader modules need a Pi-specific design.

## Initial source facts

- The primary profile contains 740 files.
- The default package manifest selects KDE Plasma and Plasma Login Manager,
  while additional manifests exist for XFCE, GNOME, Cinnamon, MATE, Budgie,
  Deepin, and Plasma variants.
- Calamares itself and `mylastarch-calamares-config` are package dependencies;
  only Calamares desktop launchers are present directly in the overlay.
- The source worktree already has unrelated user changes. It must remain
  read-only during this port.

## Calamares audit

The package source was found at
`/home/demo/MYLASTARCH/mylastarch-calamares-config/` and copied into this
repository under `config/calamares/`. Its original repository is clean and was
not modified.

Portable pieces include branding, locale, user creation, display-manager
selection, package cleanup, finish-page behavior, and most mount options.

Pi-specific changes required before an installation test:

- `unpackfs.conf` is hard-coded to ArchISO's
  `/run/archiso/bootmnt/arch/x86_64/` SquashFS and kernel paths.
- `initcpio.conf` names the x86 profile's `linux` kernel.
- `bootloader.conf` assumes EFI GRUB and `efibootmgr`; a normal Pi 400 boots
  through the firmware FAT partition and does not use the PC UEFI flow.
- `partition.conf` mounts the EFI System Partition at `/boot/efi`. The Pi
  image needs an explicit firmware boot-partition layout and a matching
  Calamares strategy.
- `shellprocess-before.conf` overwrites mkinitcpio hooks. Those hooks must be
  checked against the chosen AArch64 kernel/initramfs design.
- `shellprocess-final.conf` depends on the ArchISO-provided
  `mylastarch-final` helper, which also needs an architecture audit.

The next design decision is whether Calamares will install from a compressed
live root filesystem or from a prebuilt filesystem/image payload. That choice
determines the new `unpackfs`, partitioning, and boot-finalization workflow.
