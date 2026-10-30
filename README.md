# mylastarch for Raspberry Pi 400

This repository is an independent AArch64 port of the existing **mylastarch**
system. It stores migration inputs and Pi-specific installation logic without
modifying the original project.

## Target

- Device: Raspberry Pi 400
- Architecture: AArch64 (`aarch64`)
- Base: Arch Linux ARM-compatible userspace
- Goal: reproduce as many packages, services, desktop settings, dotfiles, and
  customizations from the source mylastarch system as practical

## Repository layout

- `scripts/` — inventory and installation helpers
- `inventory/` — generated facts collected from the source system
- `package-lists/` — reviewed AArch64 package lists
- `config/` — configuration intended for the Pi image
- `docs/` — migration notes and hardware-specific decisions

## Source of truth

The source is the existing ISO/Calamares project, not the operating system on
the development computer. Its ArchISO profile currently lives at:

`../dccwebsite/archiso`

That project is read-only input for this port. Files created for AArch64 stay
in this repository. The important source inputs are its package manifests,
`profiledef.sh`, `pacman.conf`, `airootfs/` overlay, bootloader configuration,
build scripts, and the installed Calamares configuration package.

The Calamares package source was imported from
`/home/demo/MYLASTARCH/mylastarch-calamares-config/` into `config/calamares/`.
The imported copy is the Pi port's working version; its source repository
remains untouched.

After the inventory is present, package lists can be divided into:

1. official packages available on AArch64;
2. AUR/source packages that can build on AArch64;
3. x86-only packages needing replacements;
4. Raspberry Pi-specific kernel, firmware, boot, video, and audio packages.

Do not run the x86 ArchISO build unchanged for the Pi, restore an x86_64 pacman
database, or copy an x86 root filesystem. This project will migrate package
intent and selected configuration into a Pi-bootable AArch64 image workflow.

The optional `collect-source-inventory.sh` helper is only for comparing an
installed system later. It is not the primary input to this port.

## Build the minimal development image

The builder creates an image file only; it never writes directly to an SD card:

```bash
sudo ./scripts/build-minimal-image.sh
```

After a failed or obsolete build, deliberately replace the output with:

```bash
sudo ./scripts/build-minimal-image.sh --replace
```

Required host tools are provided by `libarchive`, `curl`, `gnupg`, `dosfstools`,
`e2fsprogs`, `pv`, and `util-linux` on Arch Linux. Arch Linux ARM currently publishes
this rootfs from an HTTP download endpoint; authenticity is enforced by
checking both the published MD5 value and the release signature against the
pinned official release-key fingerprint. Do not bypass TLS checks with
`curl -k`. Output is written under `output/` and is never overwritten.

The first image retains the upstream development login credentials. It is for
local boot testing only; credential provisioning will be completed before a
release image is produced.

## Build the full desktop image

The full image is built natively on the Pi. The complete copy, build,
checksum, compression, and SD-writing procedure is in
[`docs/build-compress-and-write.md`](docs/build-compress-and-write.md).
