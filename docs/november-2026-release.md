# November 2026 Pi 400 release

The November refresh is built from current Arch Linux ARM repositories at image
build time. The reference system validated Linux `7.3-1`, KDE Plasma meta
`6.8-1`, Plasma Workspace `6.8.1-1`, and Plasma Desktop `6.8.1-1`. These
versions are observations, not pins; a later rebuild intentionally takes the
then-current coherent repository snapshot.

New Pi image defaults:

- Conky system monitor with Pi temperature, CPU, memory, disk, Wi-Fi, and zram
  information;
- compressed zram swap sized to half of RAM with a 2 GiB maximum;
- `lzo-rle` compression, which is supported by the current Pi kernel;
- VM parameters tuned for compressed swap;
- the previously reviewed Dolphin and XScreenSaver/menu refinements.

The live reference Pi requested `zstd` for zram, but its kernel advertised only
`lzo-rle` and `lzo`; the journal confirmed that `zstd` was rejected and the
device fell back to `lzo-rle`. The image therefore selects `lzo-rle`
explicitly and avoids a misleading boot warning.
