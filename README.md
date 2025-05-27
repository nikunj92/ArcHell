# Arch Linux Installation Helper Scripts

A collection of shell scripts for Arch Linux installation, configuration, and maintenance on dual-drive systems (focused on Alienware m18).

## System Layout

These scripts are tailored for a specific drive setup:
- `/dev/nvme0n1p1` - EFI System Partition (ESP)
- `/dev/nvme1n1p1` - Btrfs root partition with subvolumes
- `/dev/nvme1n1p2` - Home partition (ext4)

## Scripts Overview

### Installation & Setup

- `partitions.sh` - nukes the drive and recreates the base layout
- `mounter.sh` - Mounts btrfs root with subvolumes, separate /home, and ESP
- `pacstrapper.sh` - Installs base system packages tailored for Alienware m18 (intel ucode, nvidia intel etc)
- `systemd-booter.sh` - Installs systemd boot, adds entry point for systemd boot - reuse helpers made in efibootmgr_helper.sh - also needs comments regarding the files we need.

### Secure Boot Configuration

- `secureboot_keygen.sh` - Generates keys for secure boot
- `sbsign_helper.sh` - Signs EFI files with secure boot keys
- `keytool_helper.sh` - Assists with secure boot key enrollment

### Boot Management

- `efibootmgr_helper.sh` - UEFI boot entry management utilities

### Display & Session Management

- `displayuctl.sh` - Handles dynamic display configurations for Wayland (and X11 as fallback)
- `sessionctl.sh` - Session launcher primarily for Wayland (X11 option available)
- `gpumngrer.sh` - Manages GPU power states and environment settings with power profile integration, optimized for Wayland
- `hybrid-status.sh` - Diagnostic tool (Wayland-focused) that analyzes hybrid graphics setup and suggests fixes

### Filesystem Management

- `btrfs_snapper.sh` - Manages Btrfs snapshots creation and retention

## Dotfiles

This repository includes a set of configuration files ("dotfiles") for Xorg, systemd-boot, mkinitcpio, and GPU hybrid setups. These files are located in the `dotfiles/` directory and are intended to be copied to their respective system locations after installation.

### Xorg Configuration

- **Note**: With a Wayland-first approach, these X11 server-specific configurations (`10-modesetting.conf`, `10-nvidia-prime.conf`, `20-server-layout.conf`) may not be necessary. XWayland provides compatibility for X11 applications within a Wayland session. They are kept in dotfiles for reference or fallback scenarios but are not actively deployed by default in a strict Wayland setup.

- **10-modesetting.conf**  
  `/etc/X11/xorg.conf.d/10-modesetting.conf`  
  Configures the Intel GPU to use the `modesetting` driver for Xorg.

- **10-nvidia-prime.conf**  
  `/etc/X11/xorg.conf.d/10-nvidia-prime.conf`  
  Configures the NVIDIA GPU for PRIME offloading and hybrid graphics.

- **20-server-layout.conf**  
  `/etc/X11/xorg.conf.d/20-server-layout.conf`  
  Sets the Intel GPU as the default screen for Xorg sessions.

### Bootloader (systemd-boot) Entries

- **loader.conf**  
  `/boot/efi/loader/loader.conf`  
  Sets the default boot entry, timeout, and console options.

- **satyanet.conf**  
  `/boot/efi/loader/entries/satyanet.conf`  
  Main Arch Linux boot entry (Unified Kernel Image).

- **satyanet-fallback.conf**  
  `/boot/efi/loader/entries/satyanet-fallback.conf`  
  Fallback boot entry using traditional kernel/initramfs.

- **windows.conf**  
  `/boot/efi/loader/entries/windows.conf`  
  Boot entry for Windows 11.

### Initramfs and Kernel

- **mkinitcpio.conf**  
  `/etc/mkinitcpio.conf`  
  Preloads GPU modules and sets up hooks for early boot, systemd, and encryption.

- **linux-uki.preset**  
  `/etc/mkinitcpio.d/linux-uki.preset`  
  Preset for building a Unified Kernel Image (UKI) and fallback images.

- **cmdline**  
  `/etc/kernel/cmdline`  
  Kernel command line parameters for root device, subvolume, and boot options including NVIDIA modules (`nvidia-drm.modeset=1`).

### GPU and Hybrid Graphics

- **blacklist.conf**  
  `/etc/modprobe.d/blacklist.conf`  
  Blacklists the Nouveau driver (and other legacy modules - commented out) to avoid conflicts.

- **99-wayland.conf**  
  `~/.config/environment.d/99_wayland.conf` (or system-wide in `/etc/environment.d/`)
  Environment variables for Wayland + NVIDIA hybrid mode with G-SYNC and VRR support.

### Wayland Autostart

- **arch_os_wayland.sh**  
  `/etc/profile.d/arch_os_wayland.sh`  
  Auto-starts Plasma Wayland session on tty1.

---

## Note: 
Copy these files to their respective locations as root after installation. Adjust UUIDs and device paths as needed for the system. See install_guide.md

## Documentation

The system includes detailed documentation:

- **graphics_guide.md** - Comprehensive guide to the hybrid graphics setup
- **README_OR_DONT.md** - Installation plan and detailed task list
- **README_REALLY** - LLM feedback and areas of improvement

## Security Note

This setup is for my personal arch. Some scripts may require root privileges. Some wipe drives. Review the code before execution. I take no responsibility for any damage caused - use at your own risk