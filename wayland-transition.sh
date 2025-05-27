#!/bin/bash

# wayland-transition.sh - Migrate from hybrid X11/Wayland to Wayland-focused setup
# Adjusts configuration and packages for optimal Wayland experience on hybrid graphics

set -euo pipefail

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

echo -e "${BLUE}=== Alienware m18 Wayland Transition Tool ===${NC}"
echo "This script will configure your system for a Wayland-first experience."
read -p "Do you want to continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[yY]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Step 1: Install required packages for Wayland
echo -e "\n${BLUE}Step 1: Installing required packages for optimal Wayland experience...${NC}"
pacman -S --needed --noconfirm \
  plasma-wayland-session plasma-wayland-protocols \
  qt5-wayland qt6-wayland \
  egl-wayland libva-nvidia-driver \
  xorg-xwayland \
  kde-cli-tools kscreen \
  glxinfo vulkan-tools \
  ttf-dejavu ttf-liberation noto-fonts \
  linux-headers nvidia-dkms

# Step 2: Update kernel command line for NVIDIA Wayland
echo -e "\n${BLUE}Step 2: Updating kernel command line for NVIDIA Wayland support...${NC}"
CMDLINE_FILE="/etc/kernel/cmdline"
if [ ! -f "$CMDLINE_FILE" ]; then
    echo -e "${YELLOW}Warning: $CMDLINE_FILE not found. Creating a default one.${NC}"
    # Attempt to get root UUID, fallback to placeholder
    ROOT_UUID=$(findmnt -no UUID / || echo "YOUR-ROOT-UUID")
    echo "root=UUID=${ROOT_UUID} rootflags=subvol=@ rw quiet splash" > "$CMDLINE_FILE"
fi

# Ensure nvidia-drm.modeset=1 is present
if ! grep -q "nvidia-drm.modeset=1" "$CMDLINE_FILE"; then
  sed -i 's/$/ nvidia-drm.modeset=1/' "$CMDLINE_FILE"
  echo -e "${GREEN}Added 'nvidia-drm.modeset=1' to $CMDLINE_FILE${NC}"
else
  echo -e "${GREEN}'nvidia-drm.modeset=1' already present in $CMDLINE_FILE${NC}"
fi

# Ensure nvidia.NVreg_PreserveVideoMemoryAllocations=1 is present
if ! grep -q "nvidia.NVreg_PreserveVideoMemoryAllocations=1" "$CMDLINE_FILE"; then
  sed -i 's/$/ nvidia.NVreg_PreserveVideoMemoryAllocations=1/' "$CMDLINE_FILE"
  echo -e "${GREEN}Added 'nvidia.NVreg_PreserveVideoMemoryAllocations=1' to $CMDLINE_FILE${NC}"
else
  echo -e "${GREEN}'nvidia.NVreg_PreserveVideoMemoryAllocations=1' already present in $CMDLINE_FILE${NC}"
fi
echo "Current $CMDLINE_FILE:"
cat "$CMDLINE_FILE"

# Step 3: Update mkinitcpio.conf to ensure NVIDIA modules are loaded early
echo -e "\n${BLUE}Step 3: Updating mkinitcpio configuration...${NC}"
MKINITCPIO_CONF="/etc/mkinitcpio.conf"
NVIDIA_MODULES="nvidia nvidia_modeset nvidia_uvm nvidia_drm"

# Check if modules are already there
if grep -q "^MODULES=.*($NVIDIA_MODULES|${NVIDIA_MODULES// /\\s}).*" "$MKINITCPIO_CONF"; then
  echo -e "${GREEN}NVIDIA modules already present in $MKINITCPIO_CONF MODULES line.${NC}"
else
  # Add NVIDIA modules to the MODULES array
  # This is a robust way to add them, even if the line is complex
  sudo sed -i.bak -E "s/^(MODULES=\([^)]*)\)/\1 ${NVIDIA_MODULES})/" "$MKINITCPIO_CONF"
  if ! grep -q "^MODULES=.*($NVIDIA_MODULES|${NVIDIA_MODULES// /\\s}).*" "$MKINITCPIO_CONF"; then # if first attempt failed
      sudo sed -i.bak -E "s/^(MODULES=)\(\)/\1(${NVIDIA_MODULES})/" "$MKINITCPIO_CONF" # For empty MODULES=()
  fi
  echo -e "${GREEN}Added NVIDIA modules to $MKINITCPIO_CONF${NC}"
fi
echo "Current MODULES line in $MKINITCPIO_CONF:"
grep "^MODULES=" "$MKINITCPIO_CONF"

# Step 4: Ensure DKMS modules are built
echo -e "\n${BLUE}Step 4: Ensuring NVIDIA DKMS modules are built...${NC}"
dkms autoinstall
echo -e "${GREEN}DKMS autoinstall completed.${NC}"
dkms status

# Step 5: Rebuild initramfs/UKI
echo -e "\n${BLUE}Step 5: Rebuilding initramfs/UKI...${NC}"
# Check if UKI preset exists, otherwise use standard preset
if [ -f /etc/mkinitcpio.d/linux-uki.preset ]; then
  mkinitcpio -p linux-uki
else
  mkinitcpio -P # Rebuild all presets (e.g., default and fallback)
fi
echo -e "${GREEN}Initramfs/UKI rebuild complete.${NC}"

# Step 6: Setup Wayland environment variables
echo -e "\n${BLUE}Step 6: Setting up Wayland environment variables...${NC}"
ENV_DIR_SYSTEM="/etc/environment.d"
ENV_FILE_WAYLAND_NVIDIA="${ENV_DIR_SYSTEM}/90-wayland-nvidia.conf"
mkdir -p "$ENV_DIR_SYSTEM"
cat > "$ENV_FILE_WAYLAND_NVIDIA" << EOF
# Wayland + NVIDIA specific environment variables
# Ensures Wayland sessions use NVIDIA drivers correctly.
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
WLR_NO_HARDWARE_CURSORS=1
LIBVA_DRIVER_NAME=nvidia

# Optional: Enable G-SYNC/VRR if supported and desired
# __GL_GSYNC_ALLOWED=1
# __GL_VRR_ALLOWED=1

# Optional: Forcing specific QT scaling behavior (HiDPI)
# QT_AUTO_SCREEN_SCALE_FACTOR=1
# QT_FONT_DPI=96 # Adjust as needed for your display
EOF
echo -e "${GREEN}Created/Updated $ENV_FILE_WAYLAND_NVIDIA${NC}"
echo "Ensure similar settings are in your user's environment if needed (~/.config/environment.d/)."
echo "The dotfiles/99-wayland.conf should handle user-specific settings."

# Step 7: Remove X11 specific configurations (optional)
echo -e "\n${BLUE}Step 7: Addressing X11 configurations...${NC}"
echo -e "${YELLOW}Since you're moving to Wayland-first, X11 server configurations might no longer be needed.${NC}"
echo -e "${YELLOW}Files like /etc/X11/xorg.conf.d/10-modesetting.conf, 10-nvidia-prime.conf, 20-server-layout.conf can potentially be removed.${NC}"
echo -e "${YELLOW}This script will NOT remove them automatically. Review and remove them manually if you are certain.${NC}"
echo -e "${YELLOW}XWayland will still allow X11 applications to run within your Wayland session.${NC}"

echo -e "\n${GREEN}Wayland transition steps completed!${NC}"
echo -e "${YELLOW}A reboot is required for all changes to take effect.${NC}"
echo "After rebooting, verify your Wayland session and NVIDIA driver functionality."
echo "Use 'hybrid-status-wayland.sh' for diagnostics."
