# Phase 2 installation procedure

The first desktop installation uses the audited package set in
`package-lists/desktop-phase1-candidates.txt`. It installs the supported Plasma
Wayland session, Plasma Login Manager, XWayland compatibility for X11
applications, Mesa's VideoCore Vulkan driver, PipeWire, and core KDE
applications. The former `plasma-x11-session` package is no longer published
by the current Arch Linux ARM Plasma repositories.

The installation deliberately omits `plasma-nm` and does not enable
NetworkManager. The working iwd plus systemd-networkd configuration remains in
charge of networking during this milestone.

The installer performs a full update, enables `plasmalogin.service` and
`bluetooth.service`, and selects `graphical.target`. It does not reboot.

## Recovery

If the graphical login fails, switch to a console with Ctrl+Alt+F2, log in as
root, and return to console boot:

```bash
systemctl disable plasmalogin.service
systemctl set-default multi-user.target
reboot
```

This does not uninstall Plasma and preserves SSH/network access for diagnosis.
