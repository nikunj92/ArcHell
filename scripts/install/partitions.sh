#!/bin/bash

# Arch Linux Partition Setup Script for Alienware m18
# Creates partitions on second NVMe drive with Btrfs root and ext4 home

set -e  # Exit on any error

LOG_DIR=
if [ ! -e $LOG_DIR]; then
    echo "Missing log directory: $LOG_DIR"
    exit 1
fi
exec > >(tee -a $LOG_DIR/disk_setup.log) 2>&1
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TARGET_DISK="/dev/nvme1n1"
ROOT_SIZE="500G"  # 500GB for root partition
ROOT_PART="${TARGET_DISK}p1"
HOME_PART="${TARGET_DISK}p2"
MOUNT_POINT="/mnt"

# Print header
echo -e "${BLUE}Arch Linux Partition Setup for Alienware m18${NC}"
echo "----------------------------------------"
echo -e "${YELLOW}This script will:${NC}"
echo "  1. Create partitions on ${TARGET_DISK}"
echo "  2. Format root partition (${ROOT_PART}) with Btrfs"
echo "  3. Create Btrfs subvolumes (@, @snapshots, @sacredData, @pkg, @log, @tmp)"
echo "  4. Format home partition (${HOME_PART}) with ext4"
echo -e "${RED}WARNING: ALL DATA ON ${TARGET_DISK} WILL BE DESTROYED!${NC}"
echo

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Confirm with user
read -p "Do you want to continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[yY]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Show current disk layout
echo -e "\n${BLUE}Current disk layout:${NC}"
lsblk "$TARGET_DISK"

# Confirm specific disk
read -p "Is this the correct disk to partition? (y/N): " disk_confirm
if [[ ! "$disk_confirm" =~ ^[yY]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Clean the disk before partitioning
echo -e "\n${GREEN}Cleaning the disk...${NC}"
wipefs -a "$TARGET_DISK"

# Create partitions
echo -e "\n${GREEN}Creating partitions...${NC}"
parted --script --align=optimal "$TARGET_DISK" \
    mklabel gpt \
    mkpart primary 1MiB "$ROOT_SIZE" \
    mkpart primary ext4 "$ROOT_SIZE" 100% \
 
# The 1MiB starting point is used for:
# - Proper alignment with physical sectors (especially for NVMe drives)
# - Leaving space for the GPT header and metadata
# - Ensuring optimal I/O performance on modern SSDs
# - Following recommended practice for NVMe drives
# - Avoiding potential issues with disk utilities that expect this alignment

# Wait for partitions to be recognized
udevadm settle

echo -e "\n${GREEN}Formatting root partition with Btrfs...${NC}"
mkfs.btrfs -f -L satyanet_root "$ROOT_PART" 

# Mount root for subvolume creation
echo -e "\n${GREEN}Creating Btrfs subvolumes...${NC}"
mkdir -p "$MOUNT_POINT"
mount "$ROOT_PART" "$MOUNT_POINT"

# Create subvolumes
btrfs subvolume create "$MOUNT_POINT/@"
btrfs subvolume create "$MOUNT_POINT/@snapshots"
btrfs subvolume create "$MOUNT_POINT/@sacredData"
btrfs subvolume create "$MOUNT_POINT/@pkg"
btrfs subvolume create "$MOUNT_POINT/@log"
btrfs subvolume create "$MOUNT_POINT/@tmp"

# Unmount to prepare for final mounting
umount "$MOUNT_POINT"

# Format home partition
echo -e "\n${GREEN}Formatting home partition with ext4...${NC}"
mkfs.ext4 -F -L satyanet_home "$HOME_PART"

# Display results
echo -e "\n${BLUE}Partition setup completed!${NC}"
echo -e "${GREEN}The following partitions were created:${NC}"
echo "  - ${ROOT_PART} : Btrfs root partition with subvolumes"
echo "  - ${HOME_PART} : ext4 home partition"
echo -e "\n${GREEN}Btrfs subvolumes created:${NC}"
echo "  - @ : System root"
echo "  - @snapshots : Base system snapshots"
echo "  - @sacredData : Sensitive data"
echo "  - @pkg : Package cache"
echo "  - @log : System logs"
echo "  - @tmp : Temp files"

echo -e "\n${YELLOW}Next steps:${NC}"
echo "  - Run mounter.sh to mount the partitions"
echo "  - Continue with pacstrapper.sh to install the base system"

echo -e "\n${GREEN}Done!${NC}"

