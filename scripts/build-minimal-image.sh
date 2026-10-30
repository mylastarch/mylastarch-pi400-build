#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_dir=$(cd -- "$script_dir/.." && pwd)

# shellcheck source=../config/image.conf
image_config=${IMAGE_CONFIG:-"$project_dir/config/image.conf"}
source "$image_config"

# os.archlinuxarm.org currently presents a TLS certificate that does not match
# its hostname. The project's own installation instructions publish this
# artifact over HTTP. Authenticity is enforced below with the signed release
# and the pinned official release-key fingerprint; do not replace this with
# curl --insecure.
rootfs_url=${ROOTFS_URL:-http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz}
download_dir=${DOWNLOAD_DIR:-"$project_dir/build/downloads"}
replace_output=false
if [[ ${1:-} == --replace ]]; then
  replace_output=true
  shift
fi
output_image=${1:-"$project_dir/output/mylastarch-pi400-minimal.img"}
rootfs_archive="$download_dir/${rootfs_url##*/}"
checksum_file="$rootfs_archive.md5"
signature_file="$rootfs_archive.sig"
release_key=${ARCHLINUXARM_RELEASE_KEY:-68B3537F39A313B3E574D06777193F152BDBE6A6}
work_dir=''
loop_device=''
boot_mount=''
root_mount=''
output_created=false
build_complete=false

required_commands=(
  bsdtar curl findmnt gpg losetup md5sum mkfs.ext4 mkfs.vfat mount
  pv sfdisk truncate umount
)

cleanup() {
  set +e
  local mounts_remain=0

  if [[ -n "$boot_mount" ]] && mountpoint -q "$boot_mount"; then
    umount "$boot_mount"
  fi
  if [[ -n "$root_mount" ]] && mountpoint -q "$root_mount"; then
    umount "$root_mount"
  fi
  if { [[ -n "$boot_mount" ]] && mountpoint -q "$boot_mount"; } ||
      { [[ -n "$root_mount" ]] && mountpoint -q "$root_mount"; }; then
    mounts_remain=1
    printf 'WARNING: an image filesystem is still mounted; preserving: %s\n' \
      "$work_dir" >&2
    printf 'No mounted image files or output image were deleted.\n' >&2
  fi
  if (( ! mounts_remain )) && [[ -n "$loop_device" ]]; then
    losetup -d "$loop_device"
  fi
  if (( ! mounts_remain )) && [[ -n "$work_dir" && -d "$work_dir" ]]; then
    rm -rf -- "$work_dir"
  fi
  if (( ! mounts_remain )) &&
      [[ "$output_created" == true && "$build_complete" != true ]]; then
    rm -f -- "$output_image" "$output_image.sha256"
  fi
}
trap cleanup EXIT

if [[ $EUID -ne 0 ]]; then
  printf 'Run this image builder as root.\n' >&2
  exit 1
fi

for command_name in "${required_commands[@]}"; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$command_name" >&2
    exit 1
  fi
done

if [[ -e "$output_image" ]]; then
  if [[ "$replace_output" == true ]]; then
    rm -f -- "$output_image" "$output_image.sha256"
  else
    printf 'Refusing to overwrite existing output: %s\n' "$output_image" >&2
    printf 'Pass --replace to deliberately rebuild it.\n' >&2
    exit 1
  fi
fi

if (( BOOT_SIZE_MIB < 256 || IMAGE_SIZE_MIB <= BOOT_SIZE_MIB + 512 )); then
  printf 'Invalid image geometry in config/image.conf\n' >&2
  exit 1
fi
if (( ${#BOOT_LABEL} > 11 || ${#ROOT_LABEL} > 16 )); then
  printf 'Filesystem label is too long in config/image.conf\n' >&2
  exit 1
fi

mkdir -p -- "$download_dir" "$(dirname -- "$output_image")"
work_dir=$(mktemp -d --tmpdir mylastarch-pi400-build.XXXXXXXX)

printf 'Preparing the signed Arch Linux ARM root filesystem.\n'
if [[ ! -f "$rootfs_archive" ]]; then
  curl --fail --location --output "$rootfs_archive.part" "$rootfs_url"
  mv -- "$rootfs_archive.part" "$rootfs_archive"
fi

curl --fail --location --output "$checksum_file" "$rootfs_url.md5"
curl --fail --location --output "$signature_file" "$rootfs_url.sig"
expected_md5=$(awk 'NR == 1 { print $1 }' "$checksum_file")
actual_md5=$(md5sum "$rootfs_archive" | awk '{ print $1 }')
if [[ -z "$expected_md5" || "$actual_md5" != "$expected_md5" ]]; then
  printf 'Root filesystem checksum mismatch.\n' >&2
  exit 1
fi

mkdir -m 0700 -- "$work_dir/gnupg"
gpg --homedir "$work_dir/gnupg" \
  --keyserver hkps://keyserver.ubuntu.com --recv-keys "$release_key"
verified_fingerprint=$(gpg --homedir "$work_dir/gnupg" --with-colons \
  --fingerprint "$release_key" | awk -F: '$1 == "fpr" { print $10; exit }')
if [[ "$verified_fingerprint" != "$release_key" ]]; then
  printf 'Unexpected Arch Linux ARM release-key fingerprint.\n' >&2
  exit 1
fi
gpg --homedir "$work_dir/gnupg" --verify "$signature_file" "$rootfs_archive"

boot_mount="$work_dir/boot"
root_mount="$work_dir/root"
mkdir -p -- "$boot_mount" "$root_mount"

printf 'Creating and partitioning the %s MiB image.\n' "$IMAGE_SIZE_MIB"
truncate -s "${IMAGE_SIZE_MIB}M" "$output_image"
output_created=true
sfdisk "$output_image" <<EOF
label: dos
unit: sectors

start=2048, size=$((BOOT_SIZE_MIB * 2048)), type=c, bootable
start=$(((BOOT_SIZE_MIB + 1) * 2048)), type=83
EOF

loop_device=$(losetup --find --show --partscan "$output_image")
boot_partition="${loop_device}p1"
root_partition="${loop_device}p2"

printf 'Formatting the boot and root filesystems.\n'
mkfs.vfat -F 32 -n "$BOOT_LABEL" "$boot_partition"
mkfs.ext4 -F -L "$ROOT_LABEL" "$root_partition"
mount "$root_partition" "$root_mount"
mount "$boot_partition" "$boot_mount"
printf 'Extracting the Arch Linux ARM root filesystem.\n'
pv --progress --timer --eta --rate --bytes "$rootfs_archive" \
  | bsdtar -xpf - -C "$root_mount"
printf 'Root filesystem extraction complete.\n'

# Some rootfs archives carry ownership metadata for their top-level `.` entry.
# The mounted target filesystem itself must always remain owned by root.
chown root:root "$root_mount"
chmod 0755 "$root_mount"

if [[ -d "$root_mount/boot" ]]; then
  cp -a "$root_mount/boot/." "$boot_mount/"
  find "$root_mount/boot" -mindepth 1 -delete
fi

# Copy overlay content as the root user without importing the development
# workstation's UID/GID. Preserving UID 1000 here would make system paths owned
# by the Pi's `alarm` user.
printf 'Applying the MyLastArch root filesystem overlay.\n'
cp -r "$project_dir/config/rootfs/." "$root_mount/"
chmod 0755 "$root_mount/usr/local/sbin/mylastarch-grow-root"
chmod 0755 "$root_mount/usr/local/sbin/mylastarch-patch-arch-update"
chmod 0755 "$root_mount/usr/local/bin/mylastarch-welcome"
chmod 0755 "$root_mount/etc/skel/Desktop/mylastarch-welcome.desktop"
# Keep the Arch Linux ARM repositories and architecture settings supplied by
# the upstream rootfs, while enabling the requested display options.
sed -i -E 's/^#[[:space:]]*Color[[:space:]]*$/Color/' \
  "$root_mount/etc/pacman.conf"
if ! grep -Eq '^[[:space:]]*ILoveCandy([[:space:]]|$)' \
    "$root_mount/etc/pacman.conf"; then
  sed -i '/^[[:space:]]*Color[[:space:]]*$/a ILoveCandy' \
    "$root_mount/etc/pacman.conf"
fi
sed -i 's/^#[[:space:]]*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' \
  "$root_mount/etc/locale.gen"
mkdir -p -- "$root_mount/etc/systemd/system/multi-user.target.wants"
ln -s ../mylastarch-grow-root.service \
  "$root_mount/etc/systemd/system/multi-user.target.wants/mylastarch-grow-root.service"

printf 'LABEL=%s  /      ext4  defaults,noatime  0 1\n' "$ROOT_LABEL" \
  >"$root_mount/etc/fstab"
printf 'LABEL=%s  /boot  vfat  defaults          0 2\n' "$BOOT_LABEL" \
  >>"$root_mount/etc/fstab"

printf 'mylastarch-pi400\n' >"$root_mount/etc/hostname"
printf 'Flushing the minimal image to storage.\n'
sync

umount "$boot_mount"
umount "$root_mount"
losetup -d "$loop_device"
loop_device=''

printf 'Calculating the minimal-image checksum.\n'
(
  cd -- "$(dirname -- "$output_image")"
  output_name=$(basename -- "$output_image")
  output_size=$(stat -c %s "$output_name")
  digest=$(pv --progress --timer --eta --rate --bytes --size "$output_size" \
    "$output_name" | sha256sum)
  printf '%s  %s\n' "${digest%% *}" "$output_name" >"$output_name.sha256"
)
build_complete=true
printf 'Created %s\n' "$output_image"
printf 'Checksum: %s.sha256\n' "$output_image"
printf '\nSecurity note: the upstream development credentials remain active.\n'
printf 'Change or replace them before connecting the image to an untrusted network.\n'
