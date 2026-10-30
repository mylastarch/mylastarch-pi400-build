# Migration plan

## 1. Audit the ISO project

- Read all `packages*.x86_64` and bootstrap manifests.
- Audit `profiledef.sh`, `pacman.conf`, build scripts, and boot configuration.
- Inventory the `airootfs/` overlay, enabled service symlinks, desktop defaults,
  branding, hooks, and helper scripts.
- Import and audit the source for the `mylastarch-calamares-config` package.

## 2. Classify

- Match repository packages against the chosen AArch64 repositories.
- Inspect foreign/AUR packages for `aarch64` support and build dependencies.
- Choose replacements for x86-only software.
- Separate general mylastarch settings from Pi 400 hardware settings.

## 3. Define the Pi image base

- Select the AArch64 root filesystem, Pi-compatible kernel, firmware, and image
  construction strategy. ArchISO's x86 ISO boot path cannot simply be reused.
- Configure the Pi firmware boot partition, bootloader/kernel files, root
  filesystem, locale, networking, users, and sudo.
- Configure the VC4 graphics stack, audio, Bluetooth, and keyboard hardware.

## 4. Reproduce the system

- Install reviewed package groups.
- Deploy selected system configuration and dotfiles.
- Enable reviewed services.
- Apply themes and desktop settings after their packages are installed.

## 5. Verify

- Boot and update successfully on the Pi 400.
- Confirm graphics acceleration, HDMI/audio, Ethernet/Wi-Fi, Bluetooth, USB,
  keyboard, suspend behavior, and time synchronization.
- Compare installed packages and enabled services with the source inventory.
- Record intentional differences from the x86_64 system.
