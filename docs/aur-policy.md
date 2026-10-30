# AUR support policy

The Pi port uses `yay-bin` as its optional AUR helper. Its current official AUR
metadata explicitly provides an AArch64 release archive and checksum. The
installer builds through `makepkg` as the regular desktop user and uses sudo
only for repository dependencies and installation.

Presence in the AUR does not imply AArch64 compatibility. Before adding an AUR
package to the image, review its current PKGBUILD and `.SRCINFO`, confirm that
`aarch64` (or architecture-independent `any`) is declared, inspect sources and
dependencies, and build it on the Pi. Binary packages require an explicit
AArch64 artifact and checksum.

`arch-update` currently declares AArch64 support and recognizes Yay as an
optional AUR helper. It is built natively from its reviewed AUR recipe and
replaces the earlier custom MyLastArch notifier. On first login it enables its
XDG tray autostart entry and periodic user timer.

Chaotic-AUR is deliberately not enabled. As checked on 2026-09-18, its
`x86_64/chaotic-aur.db` exists but `aarch64/chaotic-aur.db` returns HTTP 404.
Adding the x86_64 repository to an AArch64 Pi would expose pacman to
incompatible binaries. If Chaotic-AUR publishes a real AArch64 repository in
the future, its keyring and mirrorlist can be reevaluated then.

The live Pi verification installed `yay-bin` 13.0.1-1 from AUR commit
`13e0a4754d106a9252b7479bf1b370fbe454fc48`. The reviewed metadata declared
`aarch64`, Yay reported libalpm 16.0.1, and no systemd units failed.
