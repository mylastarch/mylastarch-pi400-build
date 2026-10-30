# Package lists

Generated source inventories are kept out of Git. Reviewed lists will live here:

- `base.txt` — base operating system
- `desktop.txt` — display server, desktop/window manager, and applications
- `hardware-pi400.txt` — Pi 400 kernel, firmware, graphics, audio, and utilities
- `aur.txt` — packages intentionally built from the AUR/source
- `replacements.txt` — AArch64 substitutes for unavailable x86_64 packages

One package name per line; comments begin with `#`.

`source-default.x86_64.txt` is a read-only snapshot of the original default
ArchISO manifest. It is input to the AArch64 availability audit and is not an
installation list for the Pi.
