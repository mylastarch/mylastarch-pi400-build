# Full desktop image build

The final image is provisioned natively on the reference Pi because the host
workstation is x86_64 and cannot execute AArch64 package install scripts. The
builder creates a 20 GiB raw image, installs the union of every reviewed package
batch, builds the current AArch64 `yay-bin` and `arch-update` PKGBUILDs as an
unprivileged user,
creates `default` directly as UID 1000, enables tested services, removes unique
machine state, cleans the package cache, and writes a SHA-256 checksum.

The image retains the first-boot root expansion service for the 64 GB SD card.
It contains the requested development credentials `default`/`default` and
`root`/`root`; root SSH login remains disabled. Both passwords must be changed
before use on an untrusted network.

The Pi-specific package recipe installs only the Broadcom firmware bundle used
by the Pi 400's onboard Wi-Fi and Bluetooth. It deliberately avoids the
`linux-firmware` meta-package and its unrelated AMD, Intel, NVIDIA, Radeon, and
other vendor bundles. Optional external hardware may require adding its vendor
firmware package later. Because the upstream rootfs installs the meta-package
explicitly, the full builder removes it and the previously selected Marvell
bundle (including vendor dependencies made orphaned by that removal) before it
installs `linux-firmware-broadcom`.

The target Pacman configuration keeps the upstream Arch Linux ARM repository
definitions and enables `Color` and `ILoveCandy`. The default user's Bash
configuration is a Pi-safe adaptation of the original MyLastArch file: aliases
for available tools are retained, Paru commands use Yay, and aliases tied to
x86 firmware, GRUB, unavailable display managers, or absent utilities are
omitted. `bash-completion` remains an explicit base package.

The generated Plasma panel is fixed to the top edge, non-floating, centered,
and configured to fill the available screen width.

The November Pi profile adds a Conky desktop monitor seeded through
`/etc/skel`. It shows uptime, CPU load and temperature, memory, root storage,
Wi-Fi activity, and compressed-swap usage. A single-instance launcher delays
startup until the Plasma desktop is ready and avoids user-specific absolute
paths.

Swap is provided by `zram-generator`: half of physical RAM, capped at 2 GiB,
using the Pi kernel's supported `lzo-rle` compressor at priority 100. The VM
tuning favors compressed swap while avoiding traditional SD-card swap writes.
No disk swapfile or swap partition is created.

Arch-Update's upstream reboot detector expects the running kernel image at
`/usr/lib/modules/$(uname -r)/vmlinuz`. The `linux-aarch64` package keeps its
boot image under `/boot`, so that test reports a reboot forever. The image
applies a guarded compatibility patch that tests whether the running kernel's
module directory still exists. A Pacman post-transaction hook reapplies the
patch after compatible Arch-Update upgrades and safely skips unfamiliar future
implementations.

The final application set includes repository-native AArch64 Okular for PDF
viewing. Sublime Text 4 is built from the reviewed MyLastArch recipe stored in
`packages/sublime-text-4`; it declares `aarch64`, downloads Sublime's ARM64
release, and retains the MyLastArch in-window menu fix. `masterpdfeditor-free` is not
included because its proprietary AUR package supports only i686 and x86_64 and
is currently marked out-of-date. Resume mode handles an already-migrated
`default` account idempotently so final package additions do not require a
complete image rebuild.

Strawberry is seeded for both `/etc/skel` and the pre-created `default` home
with the original MyLastArch Navidrome demo account, saved playlist database,
shuffle mode, and resume-playback state. The user explicitly approved embedding
this limited-access credential. Its configuration and database are mode `0600`;
any image distributed beyond the intended personal systems should first have
that credential removed or replaced.

The original MyLastArch `MacSequoia-Dark` Plasma 6 Aurorae window decoration is
included and selected with its left-side window controls. Cairo-Dock removes
the desktop-switcher desklet and reserves the bottom screen edge so maximized
windows do not cover it.

Firefox receives editable first-run defaults inspired by the original Vivaldi
profile: `https://www.dccwebsite.com/` is the home/start page, the bookmarks
and traditional menu bars are initially visible, and welcome, post-update, and
default-browser prompt pages are suppressed. Vivaldi-specific dashboards,
command chains, and web panels are deliberately not copied into Firefox.
Mozilla's signed New Tab extension is installed through Firefox enterprise
policy so new tabs also load the configured homepage. Because the homepage is
not locked, changing it later changes both the startup and new-tab destination.

The desktop MIME defaults associate `text/plain` files with Sublime Text while
leaving users free to choose a different application later.

Pacman 7 performs downloads as an unprivileged target user. The host-side
temporary directory containing the mounted guest filesystem is therefore mode
0755; a default `mktemp` mode of 0700 prevents the downloader from reaching
`var/lib/pacman/sync` and causes a permission-denied database refresh.

The upstream root filesystem may not contain an initialized Pacman public
keyring. Before installing packages, the builder initializes the guest GnuPG
directory and populates the Arch Linux ARM release keys. A `--resume` mode
reopens an existing partial image so already-downloaded packages are preserved
after a provisioning failure.

The guest `/dev`, `/proc`, `/sys`, and `/run` trees are mounted with slave
propagation while packages and kernel hooks run. Cleanup recursively unmounts
the guest hierarchy. Local AUR package installation uses the host-visible path
inside the mounted root, while Pacman applies it to the selected sysroot.

Before provisioning, the builder validates essential guest paths such as
`/etc/pacman.conf` and `/usr/bin/bash`. If an unmount fails, cleanup preserves
the temporary build directory and never removes files beneath a mounted image.
An image that fails the essential-path check must be rebuilt with `--replace`;
it is not safe to resume.

Pacman's guest GnuPG agent is stopped before unmounting so its open files do
not leave an otherwise complete image busy. Finalization also enforces mode
`0755` and root ownership on the filesystem root before checksumming.
The loop device is flushed and must fully disappear before checksum creation;
the builder refuses to publish a checksum while a delayed loop association can
still modify the image.

See `build-compress-and-write.md` for the reproducible operator procedure.
