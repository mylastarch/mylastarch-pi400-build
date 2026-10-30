#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    printf 'Run this full image builder as root on an AArch64 system.\n' >&2
    exit 1
fi
if [[ $(uname -m) != aarch64 ]]; then
    printf 'This builder must run natively on AArch64.\n' >&2
    exit 1
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_dir=$(cd -- "$script_dir/.." && pwd)
release_version=2026.11.01
artifact_base="mylastarch-pi400-${release_version}-aarch64"
output=${1:-"$project_dir/output/${artifact_base}.img"}
mode=${2:-}
work_dir=''
loop_device=''
root_mount=''
guest_gpg=''

cleanup() {
    set +e
    local root_still_mounted=0

    if [[ -n "$guest_gpg" && -d "$guest_gpg" ]]; then
        gpgconf --homedir "$guest_gpg" --kill all >/dev/null 2>&1
    fi
    if [[ -n "$root_mount" ]] && mountpoint -q "$root_mount"; then
        umount --recursive "$root_mount"
    fi
    if [[ -n "$root_mount" ]] && mountpoint -q "$root_mount"; then
        root_still_mounted=1
        printf 'WARNING: image root is still mounted; preserving build directory: %s\n' \
            "$work_dir" >&2
        printf 'Unmount it before removing that directory. No mounted image files were deleted.\n' >&2
    fi
    if (( ! root_still_mounted )) && [[ -n "$loop_device" ]]; then
        losetup -d "$loop_device"
    fi
    if (( ! root_still_mounted )) && [[ -n "$work_dir" && -d "$work_dir" ]]; then
        rm -rf -- "$work_dir"
    fi
}
trap cleanup EXIT

case "$mode" in
    --resume)
        [[ -f "$output" ]] || {
            printf 'Cannot resume; image does not exist: %s\n' "$output" >&2
            exit 1
        }
        printf 'Resuming package provisioning in existing image: %s\n' "$output"
        ;;
    --replace)
        IMAGE_CONFIG="$project_dir/config/full-image.conf" \
            "$script_dir/build-minimal-image.sh" --replace "$output"
        ;;
    '')
        IMAGE_CONFIG="$project_dir/config/full-image.conf" \
            "$script_dir/build-minimal-image.sh" "$output"
        ;;
    *)
        printf 'Unknown mode: %s (expected --replace or --resume)\n' "$mode" >&2
        exit 2
        ;;
esac

# build-minimal-image.sh checksums the pristine base image. From this point on
# the full builder modifies that image, so its checksum must not survive if a
# later provisioning or cleanup step fails.
rm -f -- "$output.sha256"

work_dir=$(mktemp -d --tmpdir mylastarch-pi400-full.XXXXXXXX)
# Pacman 7 downloads as the target root's unprivileged DownloadUser. That user
# must be able to traverse the host-side temporary path into the mounted image.
chmod 0755 "$work_dir"
root_mount="$work_dir/root"
mkdir -p "$root_mount"
loop_device=$(losetup --find --show --partscan "$output")
mount "${loop_device}p2" "$root_mount"
mkdir -p \
    "$root_mount/boot" \
    "$root_mount/dev" \
    "$root_mount/proc" \
    "$root_mount/sys" \
    "$root_mount/run"
mount "${loop_device}p1" "$root_mount/boot"
mount --rbind /dev "$root_mount/dev"
mount --make-rslave "$root_mount/dev"
mount -t proc proc "$root_mount/proc"
mount --rbind /sys "$root_mount/sys"
mount --make-rslave "$root_mount/sys"
mount --rbind /run "$root_mount/run"
mount --make-rslave "$root_mount/run"

required_guest_paths=(
    etc/pacman.conf
    etc/passwd
    usr/bin/bash
    var/lib/pacman
)
for required_path in "${required_guest_paths[@]}"; do
    if [[ ! -e "$root_mount/$required_path" ]]; then
        printf 'Image validation failed: missing /%s\n' "$required_path" >&2
        printf 'Do not resume this image; rebuild it with --replace.\n' >&2
        exit 1
    fi
done

component_index="$project_dir/package-lists/full-desktop-components.txt"
package_stream="$work_dir/packages.txt"
while IFS= read -r component; do
    [[ -z "$component" || $component == \#* ]] && continue
    component_path="$project_dir/package-lists/$component"
    [[ -f "$component_path" ]] || { printf 'Missing component: %s\n' "$component_path" >&2; exit 1; }
    awk '!/^[[:space:]]*(#|$)/ {print $1}' "$component_path"
done < "$component_index" | sort -u > "$package_stream"
mapfile -t packages < "$package_stream"

# Use Arch Linux ARM's recommended GeoIP redirect rather than pinning the
# image to regional mirrors that may be slow, retired, or temporarily
# unreachable. Install this again during resume so mirror fixes take effect
# without requiring a completely fresh image.
install -m 0644 "$project_dir/config/rootfs/etc/pacman.d/mirrorlist" \
    "$root_mount/etc/pacman.d/mirrorlist"

# The upstream rootfs currently carries linux-firmware explicitly. Removing it
# from our package list is not enough: a normal upgrade would retain the meta
# package and every vendor dependency. Replace it, plus the previously selected
# optional Marvell bundle, before installing the Pi-specific package set.
obsolete_firmware=()
for firmware_package in linux-firmware linux-firmware-marvell; do
    if pacman --sysroot "$root_mount" -Q "$firmware_package" >/dev/null 2>&1; then
        obsolete_firmware+=("$firmware_package")
    fi
done
if (( ${#obsolete_firmware[@]} )); then
    printf 'Removing non-Pi firmware meta/extra packages: %s\n' \
        "${obsolete_firmware[*]}"
    pacman --sysroot "$root_mount" -Rns --noconfirm "${obsolete_firmware[@]}"
fi

guest_gpg="$root_mount/etc/pacman.d/gnupg"
if [[ ! -s "$guest_gpg/pubring.gpg" ]]; then
    printf 'Initializing the guest Pacman keyring.\n'
    install -d -m 0700 "$guest_gpg"
    pacman-key --gpgdir "$guest_gpg" --init
fi
pacman-key --gpgdir "$guest_gpg" --populate archlinuxarm

printf 'Installing %d reviewed repository packages into the image.\n' "${#packages[@]}"
package_install_complete=false
for package_attempt in 1 2 3; do
    if pacman --sysroot "$root_mount" -Syu --needed --noconfirm "${packages[@]}"; then
        package_install_complete=true
        break
    fi
    if (( package_attempt < 3 )); then
        printf 'Package download attempt %d failed; retrying in 20 seconds.\n' \
            "$package_attempt" >&2
        sleep 20
    fi
done
if [[ $package_install_complete != true ]]; then
    printf 'Package installation failed after 3 attempts.\n' >&2
    exit 1
fi

# Build yay-bin as the regular validated host user, then install the resulting
# signed-by-checksum package into the target root. Never run makepkg as root.
aur_build="$work_dir/aur-yay-bin"
install -d -m 0755 -o default -g default "$aur_build"
runuser -u default -- env HOME=/home/default bash -c '
    set -euo pipefail
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$1/repo"
    cd "$1/repo"
    makepkg --printsrcinfo > .SRCINFO.reviewed
    grep -qx $'"'"'\tarch = aarch64'"'"' .SRCINFO.reviewed
    makepkg --cleanbuild --clean --noconfirm
' bash "$aur_build"
yay_package=$(find "$aur_build/repo" -maxdepth 1 -name 'yay-bin-*.pkg.tar.*' -type f -print -quit)
[[ -n "$yay_package" ]] || { printf 'yay-bin package was not produced.\n' >&2; exit 1; }
install -m 0644 "$yay_package" "$root_mount/tmp/yay-bin-aarch64.pkg.tar.zst"
pacman --sysroot "$root_mount" -U --noconfirm \
    "$root_mount/tmp/yay-bin-aarch64.pkg.tar.zst"
rm -f "$root_mount/tmp/yay-bin-aarch64.pkg.tar.zst"

# Chaotic-AUR currently publishes an x86_64 repository only. Enabling it on
# AArch64 would expose pacman to incompatible binaries, so build Arch-Update
# from its reviewed AUR recipe natively on the Pi instead.
pacman -S --needed --noconfirm cargo scdoc bats
arch_update_build="$work_dir/aur-arch-update"
install -d -m 0755 -o default -g default "$arch_update_build"
runuser -u default -- env HOME=/home/default bash -c '
    set -euo pipefail
    git clone --depth 1 https://aur.archlinux.org/arch-update.git "$1/repo"
    cd "$1/repo"
    makepkg --printsrcinfo > .SRCINFO.reviewed
    grep -qx $'"'"'\tarch = aarch64'"'"' .SRCINFO.reviewed
    makepkg --cleanbuild --clean --noconfirm
' bash "$arch_update_build"
arch_update_package=$(find "$arch_update_build/repo" -maxdepth 1 \
    -name 'arch-update-*.pkg.tar.*' -type f -print -quit)
[[ -n "$arch_update_package" ]] || {
    printf 'arch-update package was not produced.\n' >&2
    exit 1
}
install -m 0644 "$arch_update_package" \
    "$root_mount/tmp/arch-update-aarch64.pkg.tar.zst"
pacman --sysroot "$root_mount" -U --noconfirm \
    "$root_mount/tmp/arch-update-aarch64.pkg.tar.zst"
rm -f "$root_mount/tmp/arch-update-aarch64.pkg.tar.zst"

# Arch-Update 4.4.2 assumes that the running kernel is mirrored at
# /usr/lib/modules/$(uname -r)/vmlinuz. linux-aarch64 instead installs its
# boot image under /boot, which otherwise produces a permanent false reboot
# warning. Test the running kernel's module directory, which disappears when
# that kernel has actually been replaced. A Pacman hook reapplies this guarded
# compatibility patch after future Arch-Update package upgrades.
chroot "$root_mount" /usr/local/sbin/mylastarch-patch-arch-update
arch_update_reboot_check="$root_mount/usr/share/arch-update/lib/kernel_reboot.sh"
grep -Fqx 'kernel_modules="/usr/lib/modules/$(uname -r)"' \
    "$arch_update_reboot_check"
grep -Fqx 'if ! [ -d "${kernel_modules}" ]; then' \
    "$arch_update_reboot_check"

# Sublime Text publishes a native ARM64 build. Build the reviewed, versioned
# MyLastArch recipe as the unprivileged host user and install it into the
# selected sysroot. Master PDF Editor Free is omitted because its proprietary
# AUR package declares only i686 and x86_64.
sublime_recipe="$project_dir/packages/sublime-text-4"
[[ -f "$sublime_recipe/PKGBUILD" ]] || {
    printf 'Missing Sublime Text package recipe: %s\n' "$sublime_recipe" >&2
    exit 1
}
sublime_build="$work_dir/sublime-text-4"
install -d -m 0755 -o default -g default "$sublime_build"
cp -a "$sublime_recipe/." "$sublime_build/"
chown -R default:default "$sublime_build"
runuser -u default -- env HOME=/home/default bash -c '
    set -euo pipefail
    cd "$1"
    makepkg --printsrcinfo > .SRCINFO.reviewed
    grep -qx $'"'"'\tarch = aarch64'"'"' .SRCINFO.reviewed
    makepkg --cleanbuild --clean --noconfirm
' bash "$sublime_build"
sublime_package=$(find "$sublime_build" -maxdepth 1 \
    -name 'sublime-text-4-*.pkg.tar.*' -type f -print -quit)
[[ -n "$sublime_package" ]] || {
    printf 'sublime-text-4 package was not produced.\n' >&2
    exit 1
}
install -m 0644 "$sublime_package" \
    "$root_mount/tmp/sublime-text-4-aarch64.pkg.tar.zst"
pacman --sysroot "$root_mount" -U --noconfirm \
    "$root_mount/tmp/sublime-text-4-aarch64.pkg.tar.zst"
rm -f "$root_mount/tmp/sublime-text-4-aarch64.pkg.tar.zst"

# Seed Strawberry with the explicitly approved limited Navidrome demo account,
# saved playlist database, and resume-playback state. These files contain a
# credential and therefore remain readable only by their owning user.
strawberry_skel="$project_dir/config/rootfs/etc/skel"
install -D -m 0600 \
    "$strawberry_skel/.config/strawberry/strawberry.conf" \
    "$root_mount/etc/skel/.config/strawberry/strawberry.conf"
install -D -m 0600 \
    "$strawberry_skel/.local/share/strawberry/strawberry/strawberry.db" \
    "$root_mount/etc/skel/.local/share/strawberry/strawberry/strawberry.db"

# Replace the upstream development account before creating the final user so
# default receives UID/GID 1000 on a newly built image.
if chroot "$root_mount" getent passwd alarm >/dev/null; then
    chroot "$root_mount" userdel --remove alarm
fi
if ! chroot "$root_mount" getent passwd default >/dev/null; then
    chroot "$root_mount" useradd --uid 1000 --create-home --groups wheel --shell /bin/bash default
else
    chroot "$root_mount" usermod --append --groups wheel --shell /bin/bash default
fi
default_uid=$(chroot "$root_mount" id -u default)
default_gid=$(chroot "$root_mount" id -g default)
install -d -m 0700 -o "$default_uid" -g "$default_gid" \
    "$root_mount/home/default/.config/strawberry" \
    "$root_mount/home/default/.local/share/strawberry/strawberry"
install -m 0600 -o "$default_uid" -g "$default_gid" \
    "$root_mount/etc/skel/.config/strawberry/strawberry.conf" \
    "$root_mount/home/default/.config/strawberry/strawberry.conf"
install -m 0600 -o "$default_uid" -g "$default_gid" \
    "$root_mount/etc/skel/.local/share/strawberry/strawberry/strawberry.db" \
    "$root_mount/home/default/.local/share/strawberry/strawberry/strawberry.db"
# Remove the retired custom notifier when resuming an older image.
rm -f \
    "$root_mount/usr/local/bin/mylastarch-update-notifier" \
    "$root_mount/etc/skel/.config/autostart/mylastarch-update-notifier.desktop" \
    "$root_mount/home/default/.config/autostart/mylastarch-update-notifier.desktop"
printf 'default:default\nroot:root\n' | chroot "$root_mount" chpasswd
install -d -m 0750 "$root_mount/etc/sudoers.d"
printf '%%wheel ALL=(ALL:ALL) ALL\n' > "$root_mount/etc/sudoers.d/10-wheel"
chmod 0440 "$root_mount/etc/sudoers.d/10-wheel"
chroot "$root_mount" visudo -cf /etc/sudoers

chroot "$root_mount" locale-gen
ln -sfn /usr/share/zoneinfo/America/New_York "$root_mount/etc/localtime"
printf 'America/New_York\n' > "$root_mount/etc/timezone"
ln -sfn /run/systemd/resolve/resolv.conf "$root_mount/etc/resolv.conf"
printf 'mylastarch-pi400\n' > "$root_mount/etc/hostname"
truncate -s 0 "$root_mount/etc/machine-id"
rm -f "$root_mount/var/lib/systemd/random-seed"

services=(
    avahi-daemon.service bluetooth.service cups.service cups-browsed.service
    firewalld.service iwd.service mylastarch-grow-root.service NetworkManager.service plasmalogin.service
    plm-wallpaper-sync.service plm-wallpaper-sync.timer sshd.service systemd-resolved.service
)
for service in "${services[@]}"; do
    systemctl --root="$root_mount" enable "$service"
done
systemctl --root="$root_mount" disable \
    systemd-networkd.service systemd-networkd-wait-online.service || true
systemctl --root="$root_mount" set-default graphical.target

printf 'y\ny\n' | pacman --sysroot "$root_mount" -Scc --noconfirm
chown root:root "$root_mount" "$root_mount/etc" "$root_mount/usr" "$root_mount/var"
chmod 0755 "$root_mount"
gpgconf --homedir "$guest_gpg" --kill all >/dev/null 2>&1 || true
sync

umount --recursive "$root_mount"
if mountpoint -q "$root_mount"; then
    printf 'Failed to unmount image root safely: %s\n' "$root_mount" >&2
    exit 1
fi
sync
blockdev --flushbufs "$loop_device"
# Slow SD cards and udev can retain a transient reference for more than the
# original 30-second window. Allow up to two minutes before refusing to publish
# a checksum; cleanup still preserves the image and detaches on exit.
for _loop_wait in {1..120}; do
    if [[ -z $(losetup -j "$output") ]]; then
        loop_device=''
        break
    fi
    # A transient kernel/udev reference can keep the association visible
    # briefly after unmount. Retry the exact loop device instead of abandoning
    # cleanup and relying on the EXIT trap to perform a second detach.
    losetup -d "$loop_device" 2>/dev/null || true
    sleep 1
done
if [[ -n $(losetup -j "$output") ]]; then
    # On the Pi, the first detach can remain pending until the normal cleanup
    # pass closes the last transient reference. Run that pass now so a fully
    # provisioned image can proceed to checksum creation instead of requiring
    # the caller to restart the finalization workflow.
    printf 'Loop detach is still pending; running the final cleanup pass.\n'
    cleanup
    if [[ -n $(losetup -j "$output") ]]; then
        printf 'Image still has a loop association; refusing to create a stale checksum.\n' >&2
        losetup -j "$output" >&2
        exit 1
    fi
    loop_device=''
    work_dir=''
    root_mount=''
    guest_gpg=''
fi
sync
(
    cd -- "$(dirname -- "$output")"
    output_name=$(basename -- "$output")
    output_size=$(stat -c %s "$output_name")
    digest=$(pv --progress --timer --eta --rate --bytes --size "$output_size" \
        "$output_name" | sha256sum)
    printf '%s  %s\n' "${digest%% *}" "$output_name" > "$output_name.sha256"
)
printf 'Created full desktop image: %s\n' "$output"
printf 'Checksum: %s.sha256\n' "$output"
