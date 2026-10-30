# Phase 5: desktop tweaks and validation

Before producing the full desktop image, the live Pi is used to validate the
portable desktop customizations.

## Dolphin

The original custom toolbar and service-menu actions are restored for opening
a terminal, comparing files with Meld, launching KDE Partition Manager,
opening an admin KIO location, opening DuckDuckGo AI, toggling hidden files,
and converting JPEG/PNG/WebP images. The Gittyup entry is omitted because
Gittyup is unavailable in the configured AArch64 repositories.

## XScreenSaver

MyLastArch intentionally starts XScreenSaver in the supported Plasma Wayland
session to match the existing distro behavior. Wayland operation is outside
XScreenSaver's supported secure-locking model, so XScreenSaver locking remains
disabled and Plasma continues to provide secure screen locking. The initial
profile rotates savers every two minutes, starts after ten minutes, and can use
the MyLastArch wallpaper directory.

## Plasma panel and update notifier

The Pi-safe panel keeps the original top-edge placement, `kicker` application
menu, and global-menu widget, followed by a spacer, icon task manager, system
tray, and clock. The original Intel/Optimus widget and stale live-session
geometry are intentionally omitted.

The original `arch-update` package is unavailable in the configured binary
repositories, although its AUR package supports AArch64. A small native
replacement uses `checkupdates` from `pacman-contrib` and a PyQt6 system-tray
icon. It checks every 30 minutes and only opens an interactive update terminal
when the user requests it; it never performs unattended upgrades.

The live panel verification reported top placement with widgets ordered as
Kicker, Global Menu, spacer, icon task manager, system tray, and digital clock.
The notifier dependencies and autostart file were installed successfully; a
new login is required to launch the autostart entry.

## NAS resolution, Cairo-Dock, and compact window list

Dolphin discovered the Synology NAS but tried its unqualified `diskstation`
name. Direct SMB3 access to `192.168.68.40` succeeded and listed all shares; a
temporary Samba client configuration using host/WINS/broadcast resolution also
made `//diskstation` work. That client-only configuration is included in the
image without hard-coding the NAS address.

Cairo-Dock is enabled at login with a clean Pi-safe launcher set for Dolphin,
Firefox, Konsole, LibreOffice Writer, Strawberry, Thunderbird, and System
Settings. The Plasma icon task manager is replaced by the original-style
compact Window List widget, avoiding a second row of application shortcuts.

On first start Cairo-Dock generated its standard Firefox, Thunderbird,
Konsole, and Writer entries, duplicating the initial custom copies. The custom
duplicates are removed while Cairo's defaults are retained, and a dedicated
LibreOffice Calc launcher is added.

The first live Cairo-Dock start exposed root-owned intermediate configuration
directories. The installer now recursively assigns the entire Cairo-Dock tree
to the desktop user. IPv4 mDNS is also enabled through NSS so Dolphin's
`smb://diskstation.local` URL resolves through Avahi instead of only supporting
the NetBIOS short name.

The original GPL-licensed `archsimpleblue` Plasma 6 splash theme is carried into
the Pi user profile and selected in `ksplashrc`.

For the Pi 400, KDE Num Lock is explicitly set to `1` (off), overriding the
original profile's `0` (on) because the integrated keyboard has no numeric
keypad. Cairo-Dock's detached desktop-switcher desklet is removed because the
Plasma Window List already provides application/window selection.

## Always-on power profile

The Pi desktop disables PowerDevil automatic suspend, idle dimming, and idle
display power-off. Plasma automatic screen locking and lock-on-resume are also
disabled; XScreenSaver continues to provide the selected idle visuals without
password locking. Manual Plasma locking remains available. This always-on
profile trades higher display/power use for uninterrupted desktop and network
availability.
