# Phase 3: branding

The first branding increment contains only architecture-neutral visual assets:

- the packaged MyLastArch Plasma wallpaper;
- the static Plasma Login Manager wallpaper;
- Plasma Login Manager's wallpaper configuration.
- the original Variety configuration, 5-minute rotation interval, enabled
  Wallhaven sources, starter downloads, active Plasma scripts, and delayed
  autostart entry;
- the hardened service that synchronizes Variety's current wallpaper to
  Plasma Login Manager.

The source `plasma-org.kde.plasma.desktop-appletsrc` is not imported as a
default layout. It contains live-session launchers, fixed 1280×800 geometry, a
NetworkManager applet, an Intel/Optimus widget, stale IDs, and a malformed
section. A clean Pi-appropriate layout will be built separately after the
wallpaper is verified.

The branding installer copies files individually with explicit ownership and
permissions. It does not preserve the development workstation's UID/GID and
does not restart the active display manager.

If the target user already has `~/.config/variety`, the installer moves it to
a timestamped `variety.before-mylastarch-*` backup before deploying the source
settings. Historical inactive script versions and transient state files are
not imported.

## Verified on Pi 400

- Plasma Login Manager displayed the branded wallpaper.
- Variety 0.9.1 autostarted successfully in the Plasma Wayland session.
- Variety downloaded and selected a Wallhaven space wallpaper.
- Its Plasma script changed the desktop wallpaper successfully.
- The current-wallpaper pointer is owned by `alarm` and is available to the
  hardened login-wallpaper synchronization helper on the next boot.
- No failed system services were introduced.
- Variety's tray icon additionally requires `libayatana-appindicator`; this
  dependency is included in the desktop and branding installation lists.
- After installing the AppIndicator dependency and restarting Variety, its
  system-tray icon and controls were verified working in Plasma.

## Portable appearance settings

The Pi profile keeps Papirus icons, the Vimix cursor, Noto Sans fonts, the
source green accent, wallpaper-derived accent colors, Num Lock behavior, and
useful file-dialog defaults. It deliberately does not import the source
laptop's 1.5× `eDP-1` scaling, unavailable WhiteSur/MacSequoia themes,
Vivaldi/Alacritty defaults, or wobbly-window and flip-switch effects.

The user appearance script creates a timestamped backup of affected KDE files
before changing individual keys. It does not replace the whole configuration.

The Pi verification confirmed Papirus, Vimix, and Noto Sans are installed and
selected. Wallpaper-derived accents are active, so the original green accent
acts as a seed and Plasma may change the effective `AccentColor` to match the
current Variety wallpaper.

The generated Plasma 6 panel is already clean and Pi-appropriate: application
launcher, pager, icon task manager, system tray, clock, and show-desktop. It
does not contain the source Intel/Optimus widget or Calamares/live-session
launchers, so it is retained instead of replacing the entire layout file.
