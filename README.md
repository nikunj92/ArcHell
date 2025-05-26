# Arch Linux Installation Helper Scripts

A collection of shell scripts for Arch Linux installation, configuration, and maintenance on dual-drive systems (focused on Alienware m18).

## System Layout

These scripts are tailored for a specific drive setup:
- `/dev/nvme0n1p1` - EFI System Partition (ESP)
- `/dev/nvme1n1p1` - Btrfs root partition with subvolumes
- `/dev/nvme1n1p2` - Home partition (ext4)

## Scripts Overview

### Installation & Setup

- `mounter.sh` - Mounts btrfs root with subvolumes, separate /home, and ESP
- `pacstrapper.sh` - Installs base system packages tailored for Alienware m18

### Secure Boot Configuration

- `secureboot_keygen.sh` - Generates keys for secure boot
- `sbsign_helper.sh` - Signs EFI files with secure boot keys
- `keytool_helper.sh` - Assists with secure boot key enrollment

### Boot Management

- `efibootmgr_helper.sh` - UEFI boot entry management utilities

### Display & Session Management

- `displayuctl.sh` - Handles dynamic display configurations
- `sessionctl.sh` - Session launcher for Wayland or X11

## Usage

1. Boot from an Arch Linux installation medium
2. Clone this repository: `git clone https://github.com/username/arch-helper-scripts.git`
3. Run the scripts in sequence as needed

## Example Installation Workflow

```bash
# 1. Mount partitions
./mounter.sh

# 2. Install base system
./pacstrapper.sh

# 3. Enter chroot and continue setup
arch-chroot /mnt

# 4. Generate secure boot keys
./secureboot_keygen.sh generate

# 5. Sign your kernel/bootloader
./sbsign_helper.sh sign
```

## Security Note

Some scripts require root privileges. Review the code before execution.