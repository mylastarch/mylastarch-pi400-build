# Original-profile package parity review

Review date: 2026-09-15

The original profile contains 194 unique requested packages. Of those, 169 are
available from the configured Arch Linux ARM repositories and 148 are already
installed on the Pi 400. Twenty-five are unavailable for AArch64. The remaining
21 available packages were reviewed individually below.

After installing the four reviewed parity extras, 152 of the 169 available
original-profile packages are installed. The only 17 available packages left
out are the intentional exclusions listed below.

## Safe remaining parity extras

- `grml-zsh-config`: optional Zsh configuration carried by the original profile
- `libusb-compat`: compatibility layer for older USB applications
- `linux-firmware-marvell`: firmware for optional Marvell network hardware
- `wvdial`: legacy dial-up/modem utility; inert unless explicitly configured

## Available but intentionally excluded

- `amd-ucode`: AMD x86 CPU microcode
- `arch-install-scripts`, `archinstall`: installation-environment tooling; the
  Pi release is distributed as a directly flashable image
- `b43-fwcutter`: legacy PCI Broadcom Wi-Fi tooling; the Pi uses `brcmfmac`
- `cloud-init`: cloud-instance provisioning, not needed on the desktop image
- `dmraid`: BIOS/Firmware fake-RAID support, not applicable to the Pi
- `efibootmgr`, `grub`, `os-prober`: PC EFI/GRUB boot-stack tools
- `linux-atm`: obsolete ATM networking support
- `livecd-sounds`, `mkinitcpio-archiso`: Arch ISO live-environment components
- `mkinitcpio-nfs-utils`: unnecessary unless a future NFS-root variant is built
- `qemu-guest-agent`: virtual-machine guest integration
- `sddm`: replaced by the tested Plasma Login Manager
- `sof-firmware`: firmware for Intel/x86 audio DSP hardware
- `xscreensaver`: conflicts conceptually with Plasma's screen locker

## Unavailable on AArch64

Twenty-five original packages are absent from the configured repositories.
They consist primarily of x86 boot/virtualization packages, third-party desktop
applications, Calamares branding packages, and original custom packages. The
full machine-readable list is in
`reports/aarch64-package-audit/unavailable.txt`.

Firefox replaces unavailable Vivaldi. The directly flashable, first-boot-
expanding image replaces the Calamares/ISO installation path for the Pi port.

The final verification found all four parity extras installed, working Wi-Fi,
no failed systemd units, and approximately 44 GiB free on the root filesystem.
