# AArch64 package compatibility

Audit date: 2026-09-14

The default x86 manifest contains 194 unique uncommented package requests.
The Pi's configured AArch64 repositories provide 169; 25 are unavailable.

## Remove from the Pi profile

- `b43-firmware`, `broadcom-wl`: PC Broadcom drivers; not the Pi 400's onboard
  brcmfmac firmware path.
- `hyperv`, `open-vm-tools`, `virtualbox-guest-utils-nox`: virtual-machine guest
  integrations irrelevant to physical Pi hardware.
- `intel-ucode`: x86 Intel microcode.
- `edk2-shell`, `memtest86+`, `memtest86+-efi`, `refind`, `syslinux`: PC
  BIOS/UEFI boot utilities that do not belong in the Pi firmware boot path.
- `mylastarch-viper-grub-theme`: no GRUB menu in the initial Pi design.
- `chaotic-keyring`: Chaotic-AUR publishes no AArch64 repository database; its
  x86_64 repository must not be enabled on the Pi.
- `reflector`: it manages Arch Linux mirrorlists, not the separate Arch Linux
  ARM repository mirror configuration.

Although `amd-ucode`, `efibootmgr`, and `grub` appeared available, they are
also excluded because availability does not make them appropriate for the Pi.

## Replace or redesign

- `linux`: keep the working `linux-aarch64`/U-Boot stack for now; evaluate a
  deliberate migration to `linux-rpi` later.
- `calamares`, `mylastarch-calamares-config`: build/package for AArch64 only
  after the Pi installer layout is designed.
- `yay-bin`: replace a prebuilt x86 binary with an AArch64-capable source build
  only if AUR support is needed.
- `pamac`: defer; it is not required for the first desktop boot.

## Defer proprietary or third-party applications

- `masterpdfeditor-free`
- `sublime-text-4`
- `vivaldi`

These require vendor AArch64 Linux builds or suitable replacements. They must
not block the KDE milestone.

## Defer custom/AUR utilities

- `archlinux-tweak-tool-gtk4`
- `gittyup`

`arch-update` is now built natively from its AUR recipe, which explicitly
declares AArch64 support.

These can be evaluated from source after the base desktop is stable.
