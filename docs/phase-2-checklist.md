# Phase 2: KDE Plasma desktop

## Audit before installation

- [x] Check every proposed desktop package against the live AArch64
      repositories from the Pi itself.
- [x] Separate repository packages from unavailable and third-party packages.
- [ ] Select the Pi graphics stack and verify VC4 acceleration.
- [x] Use the supported Plasma Wayland session and retain XWayland
      compatibility for X11 applications.
- [x] Select Plasma Login Manager based on AArch64 availability and
      current behavior.

## Install and configure

- [x] Install the minimal KDE Plasma session and display manager.
- [x] Install PipeWire and desktop audio controls.
- [ ] Install NetworkManager only if intentionally replacing the working
      iwd/systemd-networkd setup.
- [x] Enable Plasma Login Manager and select `graphical.target`.
- [x] Apply the staged mylastarch branding and retain the clean Pi-specific
      Plasma 6 panel instead of importing stale live-session state.

## Acceptance tests

- [x] Graphical login appears after reboot.
- [x] Plasma starts successfully in a Wayland session.
- [x] Hardware rendering is active; Wayland EGL reports Broadcom V3D rather
      than llvmpipe.
- [ ] Correct HDMI resolution and audible audio output are confirmed.
- [x] Wi-Fi still reconnects using iwd and systemd-networkd.
- [x] Bluetooth adapter is detected, powered, and pairable.
- [x] Bluetooth speaker pairs, connects, and plays test audio successfully.
- [ ] No unexplained failed services.
