#!/bin/bash

# Hybrid GPU Power Management for Intel/NVIDIA
# Controls power states and renders for better battery/performance balance

set -euo pipefail

# Check for root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Configuration
USER_NAME="${SUDO_USER:-$(logname 2>/dev/null || echo nobody)}"
USER_HOME="/home/$USER_NAME"
COMPOSITOR_RESTART_CMD="systemctl --user restart plasma-kwin_wayland.service 2>/dev/null || true"

# === Functions ===
status() {
  echo "=== GPU Power Status ==="
  
  # NVIDIA module check (lsmod)
  echo -e "\nNVIDIA Modules (lsmod):"
  if lsmod | grep -q nvidia; then
    lsmod | grep -E "^nvidia" | awk '{printf "  %-20s used by: %s\n", $1, $3 > 0 ? "yes" : "no"}'
  else
    echo "  NVIDIA modules not listed by lsmod."
  fi
  
  # NVIDIA SMI status (more reliable for driver function)
  echo -e "\nNVIDIA SMI status:"
  if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
    echo "  NVIDIA SMI: WORKING"
    nvidia-smi -q -d POWER | grep -E "Power (Draw|Limit|Management)" | sed 's/^/    /'
  else
    echo "  NVIDIA SMI: NOT WORKING or driver not fully functional."
  fi

  # Intel GPU status
  echo "Intel GPU:"
  if [ -f /sys/kernel/debug/dri/0/i915_runtime_pm_status ]; then
    cat /sys/kernel/debug/dri/0/i915_runtime_pm_status
  else
    echo "Not available (check i915 driver load status)"
  fi
  
  # Power profile status
  echo -e "\nPower Profile:"
  if command -v powerprofilesctl &>/dev/null; then
    powerprofilesctl get
  else
    echo "Power profiles daemon not installed"
  fi
  
  # NVIDIA GPU status
  echo -e "\nNVIDIA GPU:"
  if lsmod | grep -q nvidia; then
    nvidia-smi -q -d POWER || echo "NVIDIA driver loaded but smi failed"
    echo -e "\nNVIDIA Module Usage:"
    lsmod | grep nvidia | awk '{print $1" (used by: "$4")"}'
  else
    echo "NVIDIA driver not loaded"
  fi
  
  # PCIe runtime PM status for NVIDIA
  echo -e "\nNVIDIA PCIe power management:"
  if [ -f /sys/bus/pci/devices/0000:01:00.0/power/control ]; then
    cat /sys/bus/pci/devices/0000:01:00.0/power/control
  else
    echo "PCIe control not available (check device path)"
  fi
  
  # Environment variables
  echo -e "\nGPU Environment Variables:"
  sudo -u "$USER_NAME" printenv | grep -E 'NVIDIA|GLX|GBM|DRI|LIBGL|__VK' | sort
}

intel_only() {
  echo "Switching to Intel-only mode (power saving)"
  
  # Unload NVIDIA modules
  modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia || true
  
  # Set PCIe power management to auto
  if [ -f /sys/bus/pci/devices/0000:01:00.0/power/control ]; then
    echo "auto" > /sys/bus/pci/devices/0000:01:00.0/power/control
  else
    echo "Warning: PCIe control path not found"
  fi
  
  # Set power profile if available
  if command -v powerprofilesctl &>/dev/null; then
    powerprofilesctl set power-saver || true
  fi
  
  # Set environment for next login (Intel Mesa rendering)
  cat > /etc/environment.d/90-gpu-mode.conf << EOT
# Force Intel rendering for better battery life
__GLX_VENDOR_LIBRARY_NAME=mesa
GBM_BACKEND=iris
LIBVA_DRIVER_NAME=iHD
VDPAU_DRIVER=va_gl
EOT
  
  # Ensure permissions are correct
  chmod 644 /etc/environment.d/90-gpu-mode.conf
  
  echo "Done. Changes will be available after logout/reboot. To attempt immediate effect in Wayland:"
  echo "  sudo -u $USER_NAME $COMPOSITOR_RESTART_CMD"
}

nvidia_on() {
  echo "Enabling NVIDIA GPU (performance mode)"
  
  # Set PCIe power management to on
  if [ -f /sys/bus/pci/devices/0000:01:00.0/power/control ]; then
    echo "on" > /sys/bus/pci/devices/0000:01:00.0/power/control
  else
    echo "Warning: PCIe control path not found"
  fi
  
  # Remove Intel-only X11 config
  rm -f /etc/X11/xorg.conf.d/90-intel-mode.conf
  
  # Load NVIDIA modules
  modprobe nvidia nvidia_uvm nvidia_modeset nvidia_drm
  
  # Set power profile if available
  if command -v powerprofilesctl &>/dev/null; then
    powerprofilesctl set performance || true
  fi
  
  # Set environment for next login (NVIDIA rendering)
  # This should align with your main 90-wayland-nvidia.conf or dotfiles/99-wayland.conf
  cat > /etc/environment.d/90-gpu-mode.conf << EOT
# Enable NVIDIA rendering for performance
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
WLR_NO_HARDWARE_CURSORS=1 # May be needed for some Wayland compositors
LIBVA_DRIVER_NAME=nvidia # For VA-API with NVIDIA
# __GL_GSYNC_ALLOWED=1 # Uncomment if you have a G-SYNC display
# __GL_VRR_ALLOWED=1   # Uncomment for Variable Refresh Rate
KWIN_DRM_USE_MODIFIERS=1 # For KDE Plasma Wayland
EOT
  
  # Ensure permissions are correct
  chmod 644 /etc/environment.d/90-gpu-mode.conf
  
  # Copy to user's home directory for immediate effect if they source it or if systemd --user reads it
  # This might be redundant if /etc/environment.d is properly sourced by the session.
  # Consider if this is truly needed or if relying on /etc/environment.d and a reboot/re-login is cleaner.
  # For now, keeping it for potential immediate effect scenarios.
  if [ -d "$USER_HOME/.config/environment.d" ]; then
    cp /etc/environment.d/90-gpu-mode.conf "$USER_HOME/.config/environment.d/90-gpu-mode.conf"
    chown "$USER_NAME:$USER_NAME" "$USER_HOME/.config/environment.d/90-gpu-mode.conf"
  fi
  
  echo "Done. Changes will be available after logout/reboot. To attempt immediate effect in Wayland:"
  echo "  sudo -u $USER_NAME $COMPOSITOR_RESTART_CMD"
}

apply_now() {
  # Try to apply changes to running session without full logout
  echo "Attempting to apply changes to current session..."
  
  # Get current TTY
  TTY=$(sudo -u "$USER_NAME" tty 2>/dev/null)
  if [[ "$TTY" == /dev/tty* ]]; then
    echo "Console session detected, cannot apply without logout."
    return 1
  fi
  
  # Check if Wayland or X11
  WAYLAND_SESSION=$(sudo -u "$USER_NAME" printenv | grep -q WAYLAND_DISPLAY && echo "yes" || echo "no")
  
  if [[ "$WAYLAND_SESSION" == "yes" ]]; then
    echo "Restarting Wayland compositor..."
    sudo -u "$USER_NAME" $COMPOSITOR_RESTART_CMD
  else
    echo "X11 session detected - please logout and login for changes to take effect"
  fi
}

# === Main ===
case "${1:-status}" in
  status)
    status ;;
  intel)
    intel_only
    [[ "${2:-}" == "--apply" ]] && apply_now
    ;;
  nvidia)
    nvidia_on
    [[ "${2:-}" == "--apply" ]] && apply_now
    ;;
  apply)
    apply_now ;;
  *)
    echo "Usage: $0 {status|intel|nvidia|apply} [--apply]"
    echo "  status   - Show current GPU power status"
    echo "  intel    - Switch to Intel-only mode (power saving)"
    echo "  nvidia   - Enable NVIDIA GPU (performance mode)"
    echo "  apply    - Try to apply changes to current session"
    echo "  --apply  - Try to apply changes immediately after switching"
    ;;
esac