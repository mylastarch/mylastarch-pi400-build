#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_dir=$(cd -- "$script_dir/.." && pwd)
output_dir="$project_dir/output"
log_dir="$project_dir/build-logs"
release_version=2026.11.01
artifact_base="mylastarch-pi400-${release_version}-aarch64"
image="$output_dir/${artifact_base}.img"
compressed="$project_dir/${artifact_base}.img.zst"
mode=--replace
compress=true
build=true
retrieve_only=false
cleanup_only=false
cleanup_pi=ask
pi_host=192.168.68.44
pi_user=default
pi_known_hosts="$HOME/.ssh/mylastarch-pi400-known_hosts"
pi_identity="$HOME/.ssh/mylastarch-pi400-build_ed25519"
pi_control_path="$HOME/.ssh/mylastarch-pi400-control-%C"
setup_ssh_key_only=false
menu_requested=false
(($# == 0)) && menu_requested=true

usage() {
    cat <<'EOF'
Usage: ./scripts/30-build-the-pi-image.sh [options]

Build the complete MyLastArch Raspberry Pi 400 desktop image on the Pi.

Options:
  --replace       Build a fresh image (default; required for overlay changes)
  --resume        Resume package provisioning in an existing image
  --finalize-existing
                  Checksum and compress the existing image; do not build
  --no-compress   Build and verify the raw image without creating a .zst file
  --retrieve-only Copy and verify already-finished Pi artifacts on Kiro
  --cleanup-pi    Remove Pi image artifacts after successful Kiro verification
  --keep-pi-files Keep Pi image artifacts without asking after verification
  --cleanup-only  Remove previously transferred image artifacts from the Pi
  --setup-ssh-key Create and install a dedicated key for passwordless Pi SSH
  --pi-host HOST  Pi address when this script is launched on Kiro
                  (default: 192.168.68.44)
  --pi-user USER  Pi SSH user (default: default)
  -h, --help      Show this help

Examples:
  ./scripts/30-build-the-pi-image.sh
  ./scripts/30-build-the-pi-image.sh --no-compress
  ./scripts/30-build-the-pi-image.sh --resume
  ./scripts/30-build-the-pi-image.sh --finalize-existing
  ./scripts/30-build-the-pi-image.sh --retrieve-only
  ./scripts/30-build-the-pi-image.sh --retrieve-only --cleanup-pi
  ./scripts/30-build-the-pi-image.sh --setup-ssh-key

When launched on Kiro (x86_64), the script copies the project to the Pi, runs
the requested operation there, copies the finished artifacts back to Kiro, and
verifies the transferred files. On AArch64 it performs the image work locally.

Use --replace after changing config/rootfs files such as dolphinrc. Resume mode
does not recopy the general root-filesystem overlay into an existing image.
EOF
}

while (($#)); do
    case $1 in
        --replace) mode=--replace ;;
        --resume) mode=--resume ;;
        --finalize-existing) build=false ;;
        --no-compress) compress=false ;;
        --retrieve-only) retrieve_only=true ;;
        --cleanup-pi) cleanup_pi=yes ;;
        --keep-pi-files) cleanup_pi=no ;;
        --cleanup-only) cleanup_only=true ;;
        --setup-ssh-key) setup_ssh_key_only=true ;;
        --pi-host)
            (($# >= 2)) || { printf '%s\n' '--pi-host requires a value.' >&2; exit 2; }
            pi_host=$2
            shift
            ;;
        --pi-user)
            (($# >= 2)) || { printf '%s\n' '--pi-user requires a value.' >&2; exit 2; }
            pi_user=$2
            shift
            ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

phase() {
    local number=$1
    shift
    printf '\n##################################################################\n'
    if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
        tput setaf 2 || true
    fi
    printf 'Phase %s: %s\n' "$number" "$*"
    if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
        tput sgr0 || true
    fi
    printf '##################################################################\n\n'
}

calculate_sha256() {
    local artifact=$1
    local size digest
    size=$(stat -c %s "$artifact")
    digest=$(pv --progress --timer --eta --rate --bytes --size "$size" "$artifact" \
        | sha256sum)
    printf '%s\n' "${digest%% *}"
}

verify_and_normalize_checksum() {
    local artifact=$1
    local checksum_file=$2
    local recorded_name=${3:-$(basename -- "$artifact")}
    local expected actual
    expected=$(awk 'NR == 1 { print $1 }' "$checksum_file")
    [[ $expected =~ ^[[:xdigit:]]{64}$ ]] || {
        printf 'Invalid SHA-256 file: %s\n' "$checksum_file" >&2
        return 1
    }
    printf 'Reading %s for SHA-256 verification.\n' "$(basename -- "$artifact")"
    actual=$(calculate_sha256 "$artifact")
    if [[ $actual != "$expected" ]]; then
        printf '%s: FAILED\n' "$artifact" >&2
        return 1
    fi
    printf '%s: OK\n' "$artifact"
    printf '%s  %s\n' "$actual" "$recorded_name" > "$checksum_file"
}

prepare_pi_host_key() {
    local scan_file old_fingerprint new_fingerprint old_key new_key answer

    mkdir -p -- "$(dirname -- "$pi_known_hosts")"
    chmod 0700 "$(dirname -- "$pi_known_hosts")"
    scan_file=$(mktemp --tmpdir mylastarch-pi-host-key.XXXXXXXX)
    if ! ssh-keyscan -T 10 -t ed25519 "$pi_host" > "$scan_file" 2>/dev/null; then
        rm -f -- "$scan_file"
        printf 'Could not retrieve the SSH host key from %s.\n' "$pi_host" >&2
        printf 'Confirm that the Pi is powered on and connected to the network.\n' >&2
        exit 1
    fi
    [[ -s $scan_file ]] || {
        rm -f -- "$scan_file"
        printf 'The Pi did not return an ED25519 SSH host key.\n' >&2
        exit 1
    }

    new_fingerprint=$(ssh-keygen -lf "$scan_file" -E sha256 | awk 'NR == 1 {print $2}')
    new_key=$(awk 'NR == 1 {print $2 " " $3}' "$scan_file")

    if [[ -s $pi_known_hosts ]]; then
        old_key=$(awk 'NR == 1 {print $2 " " $3}' "$pi_known_hosts")
        if [[ $old_key == "$new_key" ]]; then
            rm -f -- "$scan_file"
            return
        fi
        old_fingerprint=$(ssh-keygen -lf "$pi_known_hosts" -E sha256 \
            | awk 'NR == 1 {print $2}')
        printf '\nThe Raspberry Pi SSH identity has changed.\n'
        printf 'Saved fingerprint: %s\n' "$old_fingerprint"
        printf 'Current fingerprint: %s\n' "$new_fingerprint"
        printf 'If you did not reinstall or reimage the Pi, answer no and investigate.\n'
        printf 'Was this Pi reinstalled or reimaged? Replace the saved key? [y/N]: '
    else
        printf '\nFirst connection to this Pi build target.\n'
        printf 'SSH fingerprint: %s\n' "$new_fingerprint"
        printf 'Trust and save this Pi host key? [y/N]: '
    fi

    if [[ ! -t 0 ]]; then
        rm -f -- "$scan_file"
        printf '\nInteractive confirmation is required for a new or changed Pi host key.\n' >&2
        exit 1
    fi
    read -r answer
    if [[ $answer != [Yy] && $answer != [Yy][Ee][Ss] ]]; then
        rm -f -- "$scan_file"
        printf 'Pi host key was not changed; build cancelled.\n' >&2
        exit 1
    fi

    install -m 0600 "$scan_file" "$pi_known_hosts"
    rm -f -- "$scan_file"
    printf 'Saved the verified Pi key in %s\n' "$pi_known_hosts"
}

setup_pi_ssh_key() {
    command -v ssh-copy-id >/dev/null 2>&1 || {
        printf 'Required command is missing on Kiro: ssh-copy-id\n' >&2
        exit 1
    }

    if [[ ! -f $pi_identity ]]; then
        printf 'Creating a dedicated MyLastArch Pi build SSH key.\n'
        ssh-keygen -t ed25519 -N '' -f "$pi_identity" \
            -C "mylastarch-pi400-build@$HOSTNAME"
    fi
    [[ -f $pi_identity.pub ]] || {
        ssh-keygen -y -f "$pi_identity" > "$pi_identity.pub"
        chmod 0644 "$pi_identity.pub"
    }

    printf '\nInstalling the build key on %s@%s.\n' "$pi_user" "$pi_host"
    printf 'Enter the Pi login password when requested.\n'
    ssh-copy-id -i "$pi_identity.pub" -F /dev/null \
        -o "UserKnownHostsFile=$pi_known_hosts" \
        -o StrictHostKeyChecking=yes \
        "$pi_user@$pi_host"

    printf '\nTesting passwordless SSH access.\n'
    ssh -F /dev/null -i "$pi_identity" \
        -o "UserKnownHostsFile=$pi_known_hosts" \
        -o StrictHostKeyChecking=yes \
        -o BatchMode=yes "$pi_user@$pi_host" true
    printf 'Dedicated Pi build SSH key is working.\n'
    printf 'Future builds should ask only for the remote sudo password.\n'
}

choose_kiro_action() {
    printf '\nMyLastArch Pi 400 image builder\n'
    printf '%s\n' '--------------------------------'
    printf '%s\n' '1) Fresh build, transfer, and verify'
    printf '%s\n' '2) Resume an interrupted build, transfer, and verify'
    printf '%s\n' '3) Finalize an existing image, transfer, and verify'
    printf '%s\n' '4) Retrieve and verify already-finished artifacts'
    printf '%s\n' '5) Remove generated image artifacts from the Pi'
    printf '%s\n' '6) Set up passwordless SSH for Pi builds'
    printf '%s\n' '7) Quit'
    printf '\nChoose an option [1-7]: '
    read -r menu_choice
    case $menu_choice in
        1) mode=--replace; build=true ;;
        2) mode=--resume; build=true ;;
        3) build=false ;;
        4) retrieve_only=true ;;
        5) cleanup_only=true ;;
        6) setup_ssh_key_only=true ;;
        7) printf 'No changes made.\n'; exit 0 ;;
        *) printf 'Invalid menu choice.\n' >&2; exit 2 ;;
    esac
}

remove_pi_artifacts() {
    local remote_project=$1
    local remote_image="$remote_project/output/$(basename -- "$image")"
    local remote_compressed="$remote_project/$(basename -- "$compressed")"
    phase cleanup 'Removing generated image artifacts from the Pi'
    local -a identity_args=()
    [[ -f $pi_identity ]] && identity_args=(-i "$pi_identity")
    ssh -F /dev/null "${identity_args[@]}" \
        -o "UserKnownHostsFile=$pi_known_hosts" -o StrictHostKeyChecking=yes \
        -o ControlMaster=auto -o ControlPersist=15m \
        -o "ControlPath=$pi_control_path" \
        -o ServerAliveInterval=15 -o ServerAliveCountMax=20 -o TCPKeepAlive=yes \
        -t "$pi_user@$pi_host" \
        "if [[ -n \$(sudo losetup -j '$remote_image') ]]; then
    printf '%s\\n' 'The raw image is attached to a loop device; cleanup refused.' >&2
    sudo losetup -j '$remote_image' >&2
    exit 1
fi
sudo rm -f -- \
'$remote_image' \
'$remote_image.sha256' \
'$remote_compressed' \
'$remote_compressed.sha256'"
    printf 'Removed the raw image, compressed image, and their checksums from the Pi.\n'
    printf 'The Pi project source and build logs were retained.\n'
}

run_from_kiro() {
    local remote_project="/home/$pi_user/mylastarch-pi400-build"
    local remote_mode=--replace
    local -a remote_args=()
    local transfer_ssh quoted_identity
    local -a identity_args=()
    [[ -f $pi_identity ]] && identity_args=(-i "$pi_identity")
    transfer_ssh="ssh -F /dev/null -o UserKnownHostsFile=$pi_known_hosts -o StrictHostKeyChecking=yes -o ControlMaster=auto -o ControlPersist=15m -o ControlPath=$pi_control_path -o ServerAliveInterval=30 -o ServerAliveCountMax=6"
    if [[ -f $pi_identity ]]; then
        printf -v quoted_identity '%q' "$pi_identity"
        transfer_ssh+=" -i $quoted_identity"
    fi

    for command_name in ssh ssh-keygen ssh-keyscan rsync sha256sum pv stat; do
        command -v "$command_name" >/dev/null 2>&1 || {
            printf 'Required command is missing on Kiro: %s\n' "$command_name" >&2
            exit 1
        }
    done
    prepare_pi_host_key

    if $setup_ssh_key_only; then
        setup_pi_ssh_key
        return
    fi

    if $cleanup_only; then
        printf 'This removes only generated image artifacts from:\n%s@%s:%s\n' \
            "$pi_user" "$pi_host" "$remote_project"
        printf 'Continue? [y/N]: '
        read -r cleanup_answer
        if [[ $cleanup_answer == [Yy] || $cleanup_answer == [Yy][Ee][Ss] ]]; then
            remove_pi_artifacts "$remote_project"
        else
            printf 'Cleanup cancelled; no files were removed.\n'
        fi
        return
    fi
    [[ $mode == --resume ]] && remote_mode=--resume
    if ! $build; then
        remote_args+=(--finalize-existing)
    else
        remote_args+=("$remote_mode")
    fi
    $compress || remote_args+=(--no-compress)

    $compress && command -v zstd >/dev/null 2>&1 || {
        if $compress; then
            printf 'Required command is missing on Kiro: zstd\n' >&2
            exit 1
        fi
    }

    if ! $retrieve_only; then
        phase 1 'Copying the project from Kiro to the Pi'
        printf 'Pi            : %s@%s\n' "$pi_user" "$pi_host"
        printf 'Remote project: %s\n' "$remote_project"
        rsync -a --delete -e "$transfer_ssh" \
            --exclude output/ \
            --exclude build-logs/ \
            --exclude '*.img' \
            --exclude '*.img.zst' \
            --exclude secrets/ \
            "$project_dir/" "$pi_user@$pi_host:$remote_project/"

        phase 2 'Running the image workflow on the Pi'
        printf 'The Pi may ask for its SSH password and then its sudo password.\n\n'
        ssh -F /dev/null "${identity_args[@]}" \
            -o "UserKnownHostsFile=$pi_known_hosts" -o StrictHostKeyChecking=yes \
            -o ControlMaster=auto -o ControlPersist=15m \
            -o "ControlPath=$pi_control_path" \
            -o ServerAliveInterval=15 -o ServerAliveCountMax=20 -o TCPKeepAlive=yes \
            -t "$pi_user@$pi_host" \
            "cd '$remote_project' && ./scripts/30-build-the-pi-image.sh ${remote_args[*]}"
    else
        phase 1 'Using the already-finished image on the Pi'
        printf 'No build, checksum calculation, or compression will be repeated.\n'
    fi

    phase 3 'Copying the completed artifacts back to Kiro'
    mkdir -p -- "$output_dir"
    if [[ ! -w $output_dir || (-e $image && ! -w $image) ]]; then
        printf 'The local output directory contains root-owned build files.\n'
        printf 'Restoring ownership to %s before transfer.\n' "$USER"
        sudo chown -R "$(id -u):$(id -g)" "$output_dir"
    fi
    rsync -ah --info=progress2 --partial-dir=.rsync-partial \
        -e "$transfer_ssh" \
        "$pi_user@$pi_host:$remote_project/output/$(basename -- "$image")" \
        "$pi_user@$pi_host:$remote_project/output/$(basename -- "$image").sha256" \
        "$output_dir/"
    if $compress; then
        rsync -ah --info=progress2 --partial-dir=.rsync-partial \
            -e "$transfer_ssh" \
            "$pi_user@$pi_host:$remote_project/$(basename -- "$compressed")" \
            "$pi_user@$pi_host:$remote_project/$(basename -- "$compressed").sha256" \
            "$project_dir/"
    fi

    phase 4 'Verifying the copies on Kiro'
    verify_and_normalize_checksum \
        "$image" "$image.sha256" "output/$(basename -- "$image")"
    if $compress; then
        verify_and_normalize_checksum "$compressed" "$compressed.sha256"
        zstd -t "$compressed"
    fi

    phase 5 'DONE — image is ready on Kiro'
    printf 'Raw image     : %s\n' "$image"
    if $compress; then
        printf 'SD-card source: %s\n' "$compressed"
    fi

    if [[ $cleanup_pi == ask && -t 0 ]]; then
        printf '\nKiro verification succeeded. Remove generated image artifacts from the Pi? [y/N]: '
        read -r cleanup_answer
        if [[ $cleanup_answer == [Yy] || $cleanup_answer == [Yy][Ee][Ss] ]]; then
            cleanup_pi=yes
        else
            cleanup_pi=no
        fi
    fi
    if [[ $cleanup_pi == yes ]]; then
        remove_pi_artifacts "$remote_project"
    else
        printf 'Generated image artifacts were retained on the Pi.\n'
    fi
}

case $(uname -m) in
    x86_64)
        $menu_requested && choose_kiro_action
        run_from_kiro
        exit 0
        ;;
    aarch64)
        if $retrieve_only; then
            printf '%s\n' '--retrieve-only must be run on Kiro, not on the Pi.' >&2
            exit 2
        fi
        ;;
    *)
        printf 'Unsupported build-controller architecture: %s\n' "$(uname -m)" >&2
        exit 1
        ;;
esac

if ((EUID == 0)); then
    printf 'Run this wrapper as the regular default user, not as root.\n' >&2
    printf 'It will use sudo only for the image-building step.\n' >&2
    exit 1
fi

for command_name in sudo sha256sum tee; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf 'Required command is missing: %s\n' "$command_name" >&2
        exit 1
    }
done
if $compress && ! command -v zstd >/dev/null 2>&1; then
    printf 'Compression requested, but zstd is not installed.\n' >&2
    exit 1
fi

mkdir -p -- "$output_dir" "$log_dir"
timestamp=$(date +%Y.%m.%d-%H%M%S)
log_file="$log_dir/pi-image-build-$timestamp.log"

phase 1 'Checking build settings'
printf 'Architecture : %s\n' "$(uname -m)"
printf 'Project      : %s\n' "$project_dir"
printf 'Image        : %s\n' "$image"
printf 'Build mode   : %s\n' "$mode"
if ! $build; then
    printf 'Action       : finalize existing image without rebuilding\n'
fi
printf 'Compression  : %s\n' "$compress"
printf 'Build log    : %s\n' "$log_file"
df -h -- "$project_dir"

if [[ $mode == --resume ]]; then
    printf '\nWARNING: --resume does not import changed config/rootfs overlay files.\n'
    printf 'Use --replace for changes such as etc/skel/.config/dolphinrc.\n'
fi

phase 2 'Validating sudo access'
sudo -v

if $build; then
    phase 3 'Building the full desktop image'
    printf 'The complete builder output is also being saved to:\n%s\n\n' "$log_file"
    sudo "$script_dir/build-full-desktop-image-on-pi.sh" "$image" "$mode" \
        2>&1 | tee "$log_file"
else
    phase 3 'Checking the existing image'
    if [[ ! -f $image ]]; then
        printf 'Existing image was not found: %s\n' "$image" >&2
        exit 1
    fi
    if [[ -n $(sudo losetup -j "$image") ]]; then
        printf 'The image is attached to a loop device; refusing to checksum a live image.\n' >&2
        sudo losetup -j "$image" >&2
        exit 1
    fi
    printf 'Calculating the raw-image checksum without changing the image.\n'
    image_size=$(stat -c %s "$image")
    raw_digest=$(sudo pv --progress --timer --eta --rate --bytes \
        --size "$image_size" "$image" | sha256sum)
    raw_digest=${raw_digest%% *}
    printf '%s  %s\n' "$raw_digest" "$(basename -- "$image")" \
        | sudo tee "$image.sha256" >/dev/null
fi

phase 4 'Checking the raw image checksum'
if [[ ! -f $image.sha256 ]]; then
    printf 'Build did not publish its required checksum: %s.sha256\n' "$image" >&2
    printf 'Treat the build as incomplete. Review: %s\n' "$log_file" >&2
    exit 1
fi
if $build; then
    # The full builder calculated this checksum. Read the image again here to
    # catch a post-build disk or write error before publishing it.
    (
        cd -- "$output_dir"
        sha256sum -c "$(basename -- "$image").sha256"
    )
else
    # Finalize mode just calculated the checksum above. Checking it immediately
    # would only reread the same 20 GiB file; verify it after copying to Kiro.
    printf 'Checksum created: %s.sha256\n' "$image"
    printf 'The destination copy must be verified with sha256sum -c.\n'
fi

if $compress; then
    phase 5 'Compressing the image and creating its checksum'
    # Level 3 is substantially faster on a Pi than level 15 while retaining
    # useful compression. Integrity is tested after transfer to Kiro.
    zstd -T0 -3 --sparse -f "$image" -o "$compressed"
    compressed_digest=$(calculate_sha256 "$compressed")
    printf '%s  %s\n' "$compressed_digest" "$(basename -- "$compressed")" \
        > "$compressed.sha256"
    printf 'Verify this archive after copying it to Kiro with zstd -t.\n'
else
    phase 5 'Skipping compression as requested'
fi

phase 6 'DONE'
printf 'Raw image     : %s\n' "$image"
printf 'Raw checksum  : %s.sha256\n' "$image"
if $compress; then
    printf 'Compressed    : %s\n' "$compressed"
    printf 'Zstd checksum : %s.sha256\n' "$compressed"
fi
if ! $build; then
    printf 'Build log     : not created (existing image was finalized)\n'
else
    printf 'Build log     : %s\n' "$log_file"
fi
