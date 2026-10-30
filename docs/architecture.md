# Image architecture

## Decision 001: prove a native Pi image before adding Calamares

The first deliverable is a raw, bootable disk image for Raspberry Pi 400. It
uses a two-partition layout:

1. FAT32 firmware/boot partition mounted at `/boot`;
2. ext4 root partition mounted at `/`.

The intended installation medium is a 64 GB microSD card. The development
image is 8 GiB with a 1 GiB boot partition. On first boot, partition 2 and its
ext4 filesystem expand to consume the card's remaining usable capacity. The
image must not assume that a card marketed as 64 GB has an exact fixed byte
count.

The initial system uses the kernel and U-Boot stack already supplied by the
official Arch Linux ARM Raspberry Pi AArch64 root filesystem. This keeps the
first boot close to the upstream-supported installation path. After that image
boots and updates, `linux-rpi` will be evaluated as the vendor-kernel option
for the desktop image; it conflicts with the U-Boot package and must be treated
as an intentional boot-stack migration rather than an additional package.

The first image will be deliberately small: boot, networking, SSH, package
management, sudo, and diagnostic tools. KDE, branding, the full mylastarch
package set, and Calamares are added only after this image boots and survives a
full update on the Pi 400.

## Why the existing ISO cannot be converted directly

The source profile boots with BIOS Syslinux or x86 UEFI systemd-boot and loads
an ArchISO SquashFS. Raspberry Pi 400 firmware instead expects Pi firmware,
configuration, device trees/overlays, and an ARM kernel or U-Boot payload on a
FAT boot partition. Changing package names alone would not make the ISO boot.

## Staged deliverables

1. `minimal.img`: console system that boots, obtains networking, and updates.
2. `desktop.img`: KDE Plasma, graphics acceleration, audio, and Bluetooth.
3. `mylastarch.img`: reviewed application set, branding, defaults, and tools.
4. Installer image: live environment plus Pi-aware Calamares workflow, if the
   target installation model remains desirable after the image build works.

## Calamares implications

The existing `unpackfs`, `partition`, `initcpio`, and `bootloader` modules stay
disabled from production use until the installer payload and boot-partition
contract are defined. The imported branding and user-facing configuration can
be reused earlier.
