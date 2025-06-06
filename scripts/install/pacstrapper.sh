#!/bin/bash

# Arch Linux m18 Setup - Pacstrap Installer Script
# This script installs the base system and essential packages
# tailored for the Alienware m18 hardware configuration.
# Part of the installation workflow after partitioning and mounting.

set -euo pipefail

# Mount point for the new system
MNT="/mnt"

# Ensure mount point exists and is mounted
if [ ! -d "$MNT" ]; then
  echo "Error: $MNT does not exist. Please create the mount point first."
  echo "   Hint: Use the mounter.sh script to prepare your filesystems."
  exit 1
fi

if ! mountpoint -q "$MNT"; then
  echo "Error: $MNT is not a mountpoint. Please mount your filesystems first."
  echo "   Hint: Use the mounter.sh script to prepare your filesystems."
  exit 1
fi

echo "Verifying essential mountpoints..."
if [ ! -d "$MNT/boot/efi" ] || ! mountpoint -q "$MNT/boot/efi" ]; then
  echo "Warning: EFI partition not mounted at $MNT/boot/efi"
  echo "   This is required for a bootable system."
fi

# Base packages - core system and firmware
# Includes mkinitcpio for initramfs creation and btrfs support
BASE_PACKAGES=(
  base linux linux-firmware mkinitcpio btrfs-progs
)

# Microcode for Intel hybrid CPU
CPU_MICROCODE=(
  intel-ucode
)

# Graphics - Intel + NVIDIA hybrid support with Vulkan and VA-API
GPU_PACKAGES=(
  mesa 
  vulkan-intel vulkan-tools vulkan-icd-loader
  libva-intel-driver libva-utils
  nvidia-dkms nvidia-utils nvidia-settings
  nvidia-prime egl-wayland libva-nvidia-driver # Added libva-nvidia-driver
  intel-gpu-tools
  xorg-xwayland # For X11 app compatibility in Wayland
)

# Audio stack - SOF firmware and PipeWire system
AUDIO_PACKAGES=(
  sof-firmware alsa-ucm-conf alsa-utils pipewire wireplumber pipewire-pulse
)

# Bluetooth support
BLUETOOTH_PACKAGES=(
  bluez bluez-utils
)

# Networking - systemd-integrated and wireless daemon
NETWORK_PACKAGES=(
  networkmanager iwd
)

# Wayland Session Packages (Plasma)
WAYLAND_SESSION_PACKAGES=(
  plasma-wayland-session kde-cli-tools kscreen qt5-wayland qt6-wayland
)

# Font packages
FONT_PACKAGES=(
  ttf-dejavu ttf-liberation noto-fonts noto-fonts-emoji
  # xorg-mkfontscale xorg-mkfontdir # These are for X11 font server, less critical for Wayland directly
  # xorg-fonts-misc # Also more X11 specific, Noto/DejaVu/Liberation are good modern choices
)

# Utilities - must-have tools and manual pages
UTILITY_PACKAGES=(
  git sudo vim efibootmgr dosfstools man-db man-pages
  lsof rsync htop unzip tar reflector bash-completion
  wget curl ntp terminus-fonts
)

# Combine all package arrays
ALL_PACKAGES=(
  "${BASE_PACKAGES[@]}"
  "${CPU_MICROCODE[@]}"
  "${GPU_PACKAGES[@]}"
  "${AUDIO_PACKAGES[@]}"
  "${NETWORK_PACKAGES[@]}"
  "${WAYLAND_SESSION_PACKAGES[@]}" # Added Wayland session packages
  "${FONT_PACKAGES[@]}" # Added font packages
  "${UTILITY_PACKAGES[@]}"
  "${BLUETOOTH_PACKAGES[@]}"
)

echo "Installing base system with pacstrap..."
echo "   This may take several minutes depending on your internet speed."
pacstrap "$MNT" "${ALL_PACKAGES[@]}"

echo "Base installation complete."
echo
echo "Next steps:"
echo "1. Generate fstab:           genfstab -U $MNT >> $MNT/etc/fstab"
echo "2. Enter chroot:            arch-chroot $MNT"
echo "3. Continue configuration:   Set timezone, locale, hostname, etc."
