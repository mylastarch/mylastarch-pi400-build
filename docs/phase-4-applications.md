# Phase 4: applications and utilities

Applications are installed in reviewed batches so failures and performance
regressions remain easy to isolate on the Pi 400.

## User-facing batch

The first batch contains compatible applications from the original profile:
Alacritty, Cairo-Dock, Fastfetch, Gwenview, ImageMagick, LibreOffice,
Meld, KDE Partition Manager, Strawberry, and Thunderbird.

Vivaldi is unavailable in the configured AArch64 repositories, so Firefox is
the initial native browser replacement. This does not prevent adding another
AArch64 browser later.

Cairo-Dock runs through XWayland in the current Wayland session. It is retained
for parity testing but does not replace the stable Plasma panel.

The full batch was installed and verified on AArch64. Desktop launchers are
present, the root filesystem has approximately 46 GiB free, and no failed
systemd units were introduced.

## System utility batch

The next batch restores broadly useful filesystem, storage, manual-page,
terminal, and network-diagnostic tools from the original profile. It excludes
x86 boot utilities, VM guest agents, microcode, and PC-specific drivers.

The first download attempt timed out at the Geo-IP endpoint before pacman
committed the transaction. Direct tests from the Pi selected the official
Florida mirror, with New Jersey, California, and Geo-IP as fallbacks. The
mirror selector backs up the previous list and refreshes repository databases;
pacman signature verification remains enabled.

The retry succeeded. All 26 utility packages were verified, approximately
45 GiB remains free, and no failed systemd units were introduced.

## Printing and service discovery

The printing batch restores CUPS, driverless IPP/USB support, common printer
drivers, KDE and GTK printer configuration tools, Avahi, and mDNS integration
from the original profile. Services are enabled only after package
installation succeeds.

The network-online check was adjusted to accept either wired or wireless
connectivity. This prevents an unplugged Ethernet interface from delaying CUPS
and other services when Wi-Fi is already routable.

## Desktop integration

This batch adds SMB browsing, GTK integration, KDE administrative file actions,
camera support, Cairo-Dock plug-ins, Qt tools, and PipeWire network discovery.
XScreenSaver is excluded because Plasma already manages idle locking and the
two lock managers can conflict.

All 12 packages passed the AArch64 repository audit and were installed. The
post-install check found every package present, no failed systemd units, and
approximately 45 GiB free on the root filesystem.

## Storage and recovery

The storage/recovery batch restores architecture-neutral encryption,
filesystem, disk imaging, RAID, partition recovery, and removable-media tools.
PC bootloaders, EFI utilities, OS Prober, x86 microcode, and virtual-machine
guest packages are excluded because they do not belong in the Pi boot stack.

All 21 storage/recovery packages passed the AArch64 audit and were installed.
The post-install check found every package present, no failed systemd units,
and approximately 45 GiB free on the root filesystem.

## Networking and remote connectivity

This batch restores DNS tools, terminal network utilities, VPN protocols,
iSCSI, mobile broadband, USB modem, and attached-phone support. Alternative
DHCP, Wi-Fi, and resolver managers are excluded so they cannot compete with the
working systemd-networkd, iwd, and systemd-resolved configuration.

All 17 networking packages passed the AArch64 audit and were installed. Wi-Fi
remained routable with its DHCP address and default route, optional servers
remained disabled/inactive, and no systemd units failed. Approximately 45 GiB
remains free on the root filesystem.

## Hardware, security devices, and accessibility

This batch provides firmware updating, external FIDO/OpenPGP/smart-card/TPM
support, accessibility utilities, a console font, terminal definitions, and a
simple console editor. Thunderbolt, legacy PCI Wi-Fi, SMBIOS-PC diagnostics,
and x86 audio firmware are excluded because they do not match Pi 400 hardware.

All 14 packages passed the AArch64 audit and were installed. Optional
accessibility and security-device services remained inactive, Wi-Fi remained
routable, no systemd units failed, and approximately 44 GiB remained free.
