# First boot results

Test date: 2026-09-14

## Passed

- Raspberry Pi 400 booted the AArch64 kernel successfully.
- Kernel: `7.1.6-1-aarch64-ARCH`.
- The 1 GiB FAT boot partition mounted at `/boot`.
- The one-time expansion service grew partition 2 and ext4 successfully, then
  disabled itself.
- Root capacity after expansion: 57 GiB, with 53 GiB available.
- Ethernet `end0` came up and received `192.168.68.10/24` by DHCP.
- No failed systemd units were reported.
- Local console use confirms basic HDMI and USB keyboard operation.

## Still to test

- Wi-Fi association and reconnect.
- Bluetooth discovery/pairing.
- USB mass storage.
- HDMI audio and the full graphics stack.

The Wi-Fi device `wlan0` was initially detected but had no address because its
systemd-networkd profile contained `DNCP=yes` instead of `DHCP=yes`. After
correcting `/etc/systemd/network/25-wireless.network`, wireless DHCP worked.
Automatic reconnection was then verified after reboot with Ethernet removed.

## Post-update result

- Full update and reboot completed successfully.
- Updated kernel: `linux-aarch64 7.2.5-1`.
- `systemd-timesyncd` is enabled, active, and synchronized.
- Root remains expanded with approximately 52 GiB available.
- No failed systemd units were reported after the update.
- The root device enumerated as `mmcblk0p2` after reboot instead of
  `mmcblk1p2`; label-based `fstab` entries handled this correctly.
- The configured timezone remains UTC and should be changed to the intended
  `America/New_York` setting before the desktop phase.

## Ownership issue found during desktop installation

Package hooks reported unsafe path transitions. A direct audit found that the
overlay copy had preserved UID/GID 1000 from the development workstation; on
the Pi, that identity is `alarm`. This affected `/`, `/etc`, `/etc/systemd`,
`/etc/systemd/system`, its `multi-user.target.wants` directory, `/usr`,
`/usr/local`, and `/usr/local/sbin`.

The image builder now copies overlay content as root without preserving the
development account's ownership and explicitly enforces `root:root` mode
`0755` on the filesystem root. The running test image requires a one-time,
targeted correction of the affected directories.

## First Plasma login

- Plasma Login Manager started and authenticated the `alarm` user.
- Plasma launched as a Wayland session.
- `kwin_wayland` and `plasmashell` remained active.
- Wayland EGL reports `Broadcom` and `V3D 4.2.14.0`, confirming hardware
  rendering rather than llvmpipe.
- Wi-Fi and Bluetooth services remained active.
- No failed units were reported.
- System locale is still `C`; configure `en_US.UTF-8` before applying the
  original mylastarch desktop defaults.

After generating `en_US.UTF-8` and writing `/etc/locale.conf`, Plasma Login
Manager still passed `LANG=C` into the graphical session. Its PAM stack reads
`/etc/environment`, which contained only comments. The image overlay now sets
`LANG=en_US.UTF-8` in both files and selects the US virtual-console keymap.

The per-user Plasma format file also contained `LANG=C`. It was backed up and
changed to `en_US.UTF-8`; the subsequent Plasma process environment confirmed
the UTF-8 locale.

## Audio and Bluetooth inventory

- PipeWire 1.6.8 and WirePlumber are active in the Plasma session.
- PipeWire-Pulse compatibility is active.
- ALSA detected analog headphones and both Pi HDMI audio devices.
- A default stereo sink exists; audible output still needs a listening test.
- The onboard Bluetooth controller is powered and pairable and advertises
  audio source/sink profiles.
- The initial speaker connection was blocked because another computer was
  connected to it. After releasing that connection, the Pi paired with the
  speaker and played the audio test successfully.
