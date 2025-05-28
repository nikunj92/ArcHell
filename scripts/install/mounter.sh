#!/bin/bash 

# Arch Linux m18 Setup - Mount and Prep Starter Script
# Use this script during installation or recovery from a live Arch USB
# It mounts a btrfs root with subvolumes, a separate ext4 /home, and a FAT32 EFI partition.
# Supports a dual-SSD setup and optional external NTFS backup drive.

set -euo pipefail

# === Device Definitions ===
# Configured for dual-drive Alienware m18 layout
ROOT_PART="/dev/nvme1n1p1"       # Btrfs root with subvolumes
HOME_PART="/dev/nvme1n1p2"       # Separate ext4 partition for /home
EFI_PART="/dev/nvme0n1p1"        # FAT32 ESP for UEFI bootloader (on separate drive)
EXT_BACKUP_PART="/dev/sdXn"      # Optional external NTFS backup disk

# === Mount Point Base ===
MNT="/mnt"

# === Mount Flags ===
# noatime: improves SSD longevity by avoiding frequent metadata writes
# compress=zstd: compression for btrfs subvolumes
BTRFS_OPTS="noatime,space_cache=v2,ssd,compress=zstd"



echo "Mounting additional subvolumes..."
mount -o subvol=@,"$BTRFS_OPTS" "$ROOT_PART" "$MNT/"

# Create necessary directories
mkdir -p "$MNT/boot/efi"
mkdir -p "$MNT/home"
mkdir -p "$MNT/.snapshots"
mkdir -p "$MNT/sacredData"
mkdir -p "$MNT/var/cache/pacman/pkg"
mkdir -p "$MNT/var/log"
mkdir -p "$MNT/tmp"

echo `ls -a $MNT`

mount -o subvol=@snapshots,"$BTRFS_OPTS" "$ROOT_PART" "$MNT/.snapshots"
mount -o subvol=@sacredData,"$BTRFS_OPTS" "$ROOT_PART" "$MNT/sacredData"
mount -o subvol=@pkg,"$BTRFS_OPTS" "$ROOT_PART" "$MNT/var/cache/pacman/pkg"
mount -o subvol=@log,"$BTRFS_OPTS" "$ROOT_PART" "$MNT/var/log"
mount -o subvol=@tmp,"$BTRFS_OPTS" "$ROOT_PART" "$MNT/tmp"

echo "Mounting /home (ext4)..."
mount -o noatime "$HOME_PART" "$MNT/home"

echo "Mounting EFI system partition (FAT32)..."
mount "$EFI_PART" "$MNT/boot/efi"

# Optional: Mount external NTFS backup drive if present
if blkid "$EXT_BACKUP_PART" &>/dev/null; then
  if blkid "$EXT_BACKUP_PART" | grep -q 'ntfs'; then
    echo "Mounting external NTFS backup drive..."
    mkdir -p "$MNT/mnt/backup"
    mount -o uid=1000,gid=1000,umask=022 "$EXT_BACKUP_PART" "$MNT/mnt/backup"
  else
    echo "External backup drive found but not NTFS. Skipping..."
  fi
else
  echo "External backup drive not connected. Skipping..."
fi

echo ""
echo "All mounts complete. You may now chroot with:"
echo "arch-chroot /mnt"


