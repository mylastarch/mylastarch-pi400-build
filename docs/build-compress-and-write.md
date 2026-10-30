# Build, compress, and write the Pi 400 image

Build the full image on a running AArch64 Arch Linux ARM system (the Pi), not
on the x86_64 Kiro workstation. Keep at least 45 GiB free for the 20 GiB image,
downloads, and temporary files. A wired connection is recommended.

## 1. Copy the project to the Pi

From Kiro, while the Pi is running at `192.168.68.10`:

```bash
cd "/home/demo/Documents/ChatGPT/mylastarch on pi400"
rsync -a --delete \
  --exclude output/ \
  --exclude '*.img' \
  --exclude '*.img.zst' \
  --exclude secrets/ \
  ./ default@192.168.68.10:~/mylastarch-pi400-build/
```

Do not use `--delete` if the Pi copy contains changes that have not first been
copied back to Kiro.

## 2. Build a fresh image on the Pi

For an ISO-builder-style end-to-end workflow, run the wrapper on Kiro:

```bash
cd "/home/demo/Documents/ChatGPT/mylastarch on pi400"
./scripts/30-build-the-pi-image.sh
```

On Kiro, the wrapper copies the project to the Pi, runs the native AArch64
builder, copies the raw and compressed results back, and verifies both copies.
It defaults to the Pi at `192.168.68.44`; use `--pi-host ADDRESS` after a DHCP
address change. When launched directly on the Pi, the same script performs only
the native image workflow. With no command-line options, Kiro displays a menu
for a fresh build, resume, finalization, retrieval, or Pi artifact cleanup.
After successful Kiro verification, it offers to remove the generated raw and
compressed images and their checksums from the Pi. Source files and build logs
remain available for future builds and troubleshooting.
Artifact transfers use SSH keepalives and retain partial files. If a connection
drops, run the retrieval again and rsync will verify and continue the partial
copy rather than discarding completed transfer work.

The wrapper performs a fresh `--replace` build by default. This is the required
mode after changing anything under `config/rootfs`, including `dolphinrc`. Use
`--no-compress` to leave compression for the Kiro computer. Run the script with
`--help` to see all options. Build logs are retained under `build-logs/`.

If a completed-looking image remains after an interrupted terminal session but
its checksum is missing, first confirm that it is the intended image. Then use
`--finalize-existing` to create its checksum and compress it without rebuilding.
This mode refuses to proceed while the image is attached to a loop device. It
does not reread the entire 20 GiB image immediately after calculating the
checksum; verify the destination copy on Kiro instead.

The equivalent direct builder command is:

```bash
ssh -t -i secrets/pi400_diagnostics_ed25519 default@192.168.68.10 \
  'cd "$HOME/mylastarch-pi400-build" && \
   sudo ./scripts/build-full-desktop-image-on-pi.sh \
     "$HOME/mylastarch-pi400-build/output/mylastarch-pi400-2026.11.01-aarch64.img" \
     --replace'
```

Use `--replace` after recipe changes. `--resume` is only for retrying package
provisioning in an existing, structurally valid image after a transient error.
A successful build writes the image and its `.img.sha256` file.

The builder installs build-only `cargo`, `scdoc`, and `bats` on the build Pi so
it can compile Arch-Update. It builds AUR packages as the unprivileged
`default` user; never run `makepkg` as root.

## 3. Copy the result back to Kiro

```bash
mkdir -p output
rsync -ah --info=progress2 \
  default@192.168.68.10:~/mylastarch-pi400-build/output/mylastarch-pi400-2026.11.01-aarch64.img\* \
  output/
sha256sum -c output/mylastarch-pi400-2026.11.01-aarch64.img.sha256
```

Alternatively, shut down the Pi, mount its SD card on Kiro, and copy the image
and checksum from the `default` user's build directory.

## 4. Compress and verify

```bash
zstd -T0 -15 --sparse -f \
  output/mylastarch-pi400-2026.11.01-aarch64.img \
  -o mylastarch-pi400-2026.11.01-aarch64.img.zst
sha256sum mylastarch-pi400-2026.11.01-aarch64.img.zst \
  > mylastarch-pi400-2026.11.01-aarch64.img.zst.sha256
zstd -t mylastarch-pi400-2026.11.01-aarch64.img.zst
```

Regenerate the compressed file after every image change. The `.zst` checksum
checks the cloud download; the `.img.sha256` checksum checks the raw image.

## 5. Write the compressed image to an SD card

Identify the whole SD device with `lsblk`. Replace `/dev/sdX` with the correct
whole device, never a partition such as `/dev/sdX1`:

```bash
lsblk -o NAME,SIZE,MODEL,TYPE,MOUNTPOINTS
sudo umount /dev/sdX1 2>/dev/null || true
sudo umount /dev/sdX2 2>/dev/null || true
zstd -dc mylastarch-pi400-2026.11.01-aarch64.img.zst | \
  sudo dd of=/dev/sdX bs=4M iflag=fullblock status=progress conv=fsync
sync
sudo eject /dev/sdX
```

Writing the wrong device destroys its contents, so confirm its size and model
immediately before `dd`. On first boot, the grow-root service expands the
filesystem to use the rest of a 64 GB card.
