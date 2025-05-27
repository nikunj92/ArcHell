#!/bin/bash

# hybrid-status.sh - Unified system status report for Wayland+NVIDIA
# (Symlink or copy to hybrid-status-wayland.sh if preferred)
# Reports GPU status, display and session information, and KMS status

set -euo pipefail

# === Text formatting ===
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

# Check if we need sudo for some operations
NEED_SUDO=0
if [ ! -r /sys/kernel/debug/dri/0/i915_runtime_pm_status ] || [ ! -r /sys/bus/pci/devices/0000:01:00.0/power/control ]; then
  NEED_SUDO=1
fi

print_header() {
  echo -e "${BOLD}${BLUE}$1${RESET}"
  echo -e "${BLUE}$(printf '=%.0s' $(seq 1 ${#1}))${RESET}"
}

check_gpu_modules() {
  print_header "Kernel GPU Modules"
  
  echo -e "${BOLD}Intel i915:${RESET}"
  if lsmod | grep -q i915; then
    echo -e "  ${GREEN}✓ Loaded${RESET}"
    echo "  Usage: $(lsmod | grep i915 | awk '{print $3}') dependent module(s)"
  else
    echo -e "  ${RED}✗ Not loaded${RESET}"
  fi
  
  echo -e "\n${BOLD}NVIDIA Driver Status:${RESET}"
  # Check nvidia-smi first as it's a good indicator of a working driver
  if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
    echo -e "  ${GREEN}✓ NVIDIA driver functional (nvidia-smi working)${RESET}"
    nvidia-smi -L | sed 's/^/    /'
  else
    echo -e "  ${RED}✗ NVIDIA driver not available or not functional (nvidia-smi failed)${RESET}"
  fi

  echo -e "\n${BOLD}NVIDIA Kernel Modules (lsmod):${RESET}"
  if lsmod | grep -q nvidia; then
    echo -e "  ${GREEN}✓ Base NVIDIA module(s) loaded via lsmod${RESET}"
    for mod in nvidia_drm nvidia_modeset nvidia_uvm; do
      if lsmod | grep -q $mod; then
        echo -e "  ${GREEN}✓ $mod loaded${RESET}"
      else
        echo -e "  ${RED}✗ $mod not loaded${RESET}"
      fi
    done
    
    # Check if KMS is enabled
    if [ -f /sys/module/nvidia_drm/parameters/modeset ]; then
      if [ "$(cat /sys/module/nvidia_drm/parameters/modeset)" == "Y" ]; then
        echo -e "  ${GREEN}✓ KMS enabled${RESET}"
      else
        echo -e "  ${YELLOW}! KMS disabled${RESET}"
      fi
    fi
  else
    echo -e "  ${YELLOW}✗ NVIDIA modules not listed by lsmod.${RESET}"
    echo -e "    (This can be normal if nvidia-smi works; driver might be loaded differently)"
  fi
}

check_gpu_power() {
  print_header "GPU Power Status"
  
  # Intel GPU power
  echo -e "${BOLD}Intel GPU power management:${RESET}"
  if [ $NEED_SUDO -eq 1 ]; then
    echo "  Need sudo to check Intel power status"
  elif [ -f /sys/kernel/debug/dri/0/i915_runtime_pm_status ]; then
    cat /sys/kernel/debug/dri/0/i915_runtime_pm_status
  else
    echo -e "  ${RED}✗ i915 power management info not available${RESET}"
  fi
  
  # NVIDIA GPU power
  echo -e "\n${BOLD}NVIDIA GPU power management:${RESET}"
  if [ $NEED_SUDO -eq 1 ]; then
    echo "  Need sudo to check NVIDIA power status"
  elif [ -f /sys/bus/pci/devices/0000:01:00.0/power/control ]; then
    POWER_CONTROL=$(cat /sys/bus/pci/devices/0000:01:00.0/power/control)
    if [ "$POWER_CONTROL" == "auto" ]; then
      echo -e "  PCIe power management: ${GREEN}auto${RESET} (power saving enabled)"
    else
      echo -e "  PCIe power management: ${YELLOW}on${RESET} (always on)"
    fi
    
    POWER_STATE=$(cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status)
    echo -e "  Current power state: ${YELLOW}$POWER_STATE${RESET}"
  else
    echo -e "  ${RED}✗ NVIDIA PCI power management not available${RESET}"
  fi
  
  # Check power profiles daemon if available
  if command -v powerprofilesctl &>/dev/null; then
    echo -e "\n${BOLD}System power profile:${RESET}"
    echo "  $(powerprofilesctl get)"
  fi
}

check_display_server() {
  print_header "Display Server"
  
  # Check for X11 or Wayland
  if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    echo -e "  ${GREEN}✓ Wayland session active${RESET} ($WAYLAND_DISPLAY)"
    
    # Check XDG_SESSION information
    if [ -n "${XDG_SESSION_TYPE:-}" ]; then
      echo -e "  XDG session type: ${GREEN}$XDG_SESSION_TYPE${RESET}"
    fi
    if [ -n "${XDG_CURRENT_DESKTOP:-}" ]; then
      echo -e "  XDG current desktop: ${GREEN}$XDG_CURRENT_DESKTOP${RESET}"
    fi
  elif [ -n "${DISPLAY:-}" ]; then
    echo -e "  ${YELLOW}✓ X11 session active${RESET} ($DISPLAY)"
  else
    echo -e "  ${BLUE}No graphical session detected${RESET} (running from console?)"
  fi
  
  # Check compositor details
  if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    if pgrep -f kwin_wayland >/dev/null; then
      echo -e "  ${GREEN}✓ KWin Wayland compositor running${RESET}"
    elif pgrep -f mutter >/dev/null; then
      echo -e "  ${GREEN}✓ Mutter Wayland compositor running${RESET}"
    elif pgrep -f sway >/dev/null; then
      echo -e "  ${GREEN}✓ Sway Wayland compositor running${RESET}"
    else
      echo -e "  ${YELLOW}? Unknown Wayland compositor${RESET}"
    fi
  elif [ -n "${DISPLAY:-}" ]; then
    if pgrep -f kwin_x11 >/dev/null; then
      echo -e "  ${YELLOW}✓ KWin X11 compositor running${RESET}"
    elif pgrep -f mutter >/dev/null; then
      echo -e "  ${YELLOW}✓ Mutter X11 compositor running${RESET}"
    elif pgrep -f xfwm >/dev/null; then
      echo -e "  ${YELLOW}✓ Xfwm X11 compositor running${RESET}"
    else
      echo -e "  ${YELLOW}? Unknown X11 window manager${RESET}"
    fi
  fi
  
  # Check XWayland
  if pgrep -f Xwayland >/dev/null; then
    echo -e "  ${GREEN}✓ XWayland running${RESET} (X11 compatibility layer for Wayland)"
  else
    echo -e "  ${YELLOW}! XWayland not detected${RESET} (X11 apps may not work in Wayland)"
  fi
}

check_environment() {
  print_header "Graphics Environment Variables"
  
  # Check for key environment variables
  env_vars=(
    "__GLX_VENDOR_LIBRARY_NAME"
    "GBM_BACKEND"
    "WLR_NO_HARDWARE_CURSORS"
    "LIBVA_DRIVER_NAME"
    "__GL_GSYNC_ALLOWED"
    "KWIN_DRM_USE_MODIFIERS"
    "VDPAU_DRIVER"
    "NVD_BACKEND"
    "__GL_VRR_ALLOWED"
    "QT_AUTO_SCREEN_SCALE_FACTOR"
    "QT_SCALE_FACTOR"
    "QT_FONT_DPI"
  )
  
  for var in "${env_vars[@]}"; do
    value=${!var:-}
    if [ -n "$value" ]; then
      echo -e "  ${GREEN}✓ $var=${RESET}$value"
    else
      echo -e "  ${YELLOW}✗ $var${RESET} not set"
    fi
  done
  
  # Check environment.d configuration
  echo -e "\n${BOLD}System Environment.d configurations (/etc/environment.d):${RESET}"
  if ls /etc/environment.d/*nvidia* 1> /dev/null 2>&1; then
    echo -e "  ${GREEN}✓ System-wide Wayland+NVIDIA config likely exists:${RESET}"
    ls /etc/environment.d/*nvidia* | sed 's/^/    /'
  else
    echo -e "  ${YELLOW}✗ No obvious system-wide Wayland+NVIDIA config in /etc/environment.d/${RESET}"
  fi
  
  USER_ENV_DIR="$HOME/.config/environment.d"
  echo -e "\n${BOLD}User Environment.d configurations ($USER_ENV_DIR):${RESET}"
  if [ -d "$USER_ENV_DIR" ] && ls "$USER_ENV_DIR"/*nvidia* 1> /dev/null 2>&1; then
    echo -e "  ${GREEN}✓ User Wayland+NVIDIA config likely exists:${RESET}"
    ls "$USER_ENV_DIR"/*nvidia* | sed 's/^/    /'
  elif [ -f "$USER_ENV_DIR/99_wayland.conf" ]; then # Check for the old specific name
     echo -e "  ${GREEN}✓ User Wayland config exists: $USER_ENV_DIR/99_wayland.conf${RESET}"
  else
    echo -e "  ${YELLOW}✗ No obvious user Wayland+NVIDIA config in $USER_ENV_DIR/${RESET}"
  fi
}

check_gl_info() {
  print_header "OpenGL Information"
  
  # Check which GL implementation is active
  if command -v glxinfo >/dev/null; then
    set +e
    vendor=$(glxinfo | grep "OpenGL vendor" | cut -d':' -f2 | xargs)
    renderer=$(glxinfo | grep "OpenGL renderer" | cut -d':' -f2 | xargs)
    version=$(glxinfo | grep "OpenGL version" | cut -d':' -f2 | xargs)
    
    echo -e "  OpenGL vendor: ${BOLD}$vendor${RESET}"
    echo -e "  Renderer: ${BOLD}$renderer${RESET}"
    echo -e "  Version: $version"
    
    if [[ "$vendor" == *"NVIDIA"* ]]; then
      echo -e "  ${GREEN}✓ Using NVIDIA GPU for OpenGL${RESET}"
    elif [[ "$vendor" == *"Intel"* ]]; then
      echo -e "  ${YELLOW}✓ Using Intel GPU for OpenGL${RESET}"
    else
      echo -e "  ${YELLOW}? Using unknown GPU: $vendor${RESET}"
    fi
  else
    echo "  glxinfo not installed (install mesa-utils for more information)"
  fi
}

show_kernel_parameters() {
  print_header "Kernel Parameters"
  
  if [ -f /proc/cmdline ]; then
    # Check for key kernel parameters
    cmdline=$(cat /proc/cmdline)
    echo "  $cmdline"
    echo ""
    
    if [[ "$cmdline" == *"nvidia-drm.modeset=1"* ]]; then
      echo -e "  ${GREEN}✓ nvidia-drm.modeset=1${RESET} (KMS enabled)"
    else
      echo -e "  ${RED}✗ nvidia-drm.modeset=1 not set${RESET} (KMS disabled)"
    fi
    
    if [[ "$cmdline" == *"nvidia-drm.fbdev=1"* ]]; then
      echo -e "  ${GREEN}✓ nvidia-drm.fbdev=1${RESET} (Framebuffer enabled)"
    fi
    
    if [[ "$cmdline" == *"nvidia.NVreg_PreserveVideoMemoryAllocations=1"* ]]; then
      echo -e "  ${GREEN}✓ nvidia.NVreg_PreserveVideoMemoryAllocations=1${RESET} (Memory preservation enabled)"
    else
      echo -e "  ${YELLOW}✗ nvidia.NVreg_PreserveVideoMemoryAllocations=1 not set${RESET} (Suspend/resume may have issues with NVIDIA)"
    fi
  else
    echo -e "  ${RED}✗ Unable to read kernel parameters${RESET}"
  fi
}

check_dkms_status() {
  print_header "DKMS Status"
  
  if command -v dkms &>/dev/null; then
    echo -e "${BOLD}DKMS modules:${RESET}"
    dkms status 2>/dev/null | sed 's/^/  /' || echo "  Could not query DKMS status."
    
    # Check for common issues with DKMS
    if ! dkms status | grep -q "nvidia.*OK"; then
      echo -e "  ${RED}✗ NVIDIA DKMS module not installed or not OK${RESET}"
      echo "    → Try reinstalling the NVIDIA driver or check DKMS logs."
    fi
  else
    echo "  dkms not installed (install dkms package for more information)"
  fi
}

suggest_fixes() {
  print_header "Suggestions for Wayland + NVIDIA"
  
  has_suggestions=0
  
  # Check for NVIDIA driver functional but not used by Wayland
  if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null && [ -n "${WAYLAND_DISPLAY:-}" ]; then
    if [ "${__GLX_VENDOR_LIBRARY_NAME:-}" != "nvidia" ] || [ "${GBM_BACKEND:-}" != "nvidia-drm" ]; then
        has_suggestions=1
        echo -e "  ${YELLOW}! NVIDIA driver functional, but Wayland may not be using it correctly.${RESET}"
        echo "    → Ensure environment variables are set for NVIDIA in Wayland."
        echo "      Key vars: GBM_BACKEND=nvidia-drm, __GLX_VENDOR_LIBRARY_NAME=nvidia"
        echo "      Check /etc/environment.d/ and ~/.config/environment.d/"
    fi
  fi

  # Check if KMS is disabled but NVIDIA driver is active
  if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null ; then
    if ! grep -q "nvidia-drm.modeset=1" /proc/cmdline 2>/dev/null ; then
        has_suggestions=1
        echo -e "  ${RED}! NVIDIA DRM KMS (modeset) might be disabled but is needed for Wayland.${RESET}"
        echo "    → Add 'nvidia-drm.modeset=1' to /etc/kernel/cmdline"
        echo "    → Then run: 'sudo mkinitcpio -P' (or -p linux-uki) and reboot."
    fi
  fi
  
  # Check for missing memory preservation parameter if NVIDIA is active
  if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null ; then
    if ! grep -q "nvidia.NVreg_PreserveVideoMemoryAllocations=1" /proc/cmdline 2>/dev/null ; then
        has_suggestions=1
        echo -e "  ${YELLOW}! Missing NVIDIA memory preservation parameter (nvidia.NVreg_PreserveVideoMemoryAllocations=1).${RESET}"
        echo "    → Add to /etc/kernel/cmdline to improve suspend/resume with NVIDIA."
        echo "    → Then run: 'sudo mkinitcpio -P' (or -p linux-uki) and reboot."
    fi
  fi
  
  # Check for DPI/scaling issues
  if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    if [ -z "${QT_AUTO_SCREEN_SCALE_FACTOR:-}" ] && [ -z "${QT_SCALE_FACTOR:-}" ]; then # Basic check
        has_suggestions=1
        echo -e "  ${YELLOW}! HiDPI scaling environment variables (e.g., QT_AUTO_SCREEN_SCALE_FACTOR) might be missing.${RESET}"
        echo "    → For Qt applications, consider setting QT_AUTO_SCREEN_SCALE_FACTOR=1 or QT_SCALE_FACTOR."
        echo "    → Check ~/.config/environment.d/ or /etc/environment.d/"
    fi
  fi

  # Check for XWayland
  if [ -n "${WAYLAND_DISPLAY:-}" ] && ! pgrep -f Xwayland >/dev/null; then
    has_suggestions=1
    echo -e "  ${YELLOW}! XWayland does not seem to be running.${RESET}"
    echo "    → Ensure 'xorg-xwayland' package is installed if you need to run X11 applications."
  fi
  
  if [ $has_suggestions -eq 0 ]; then
    echo -e "  ${GREEN}✓ No immediate issues detected.${RESET}"
  fi
}

# Main execution
if [ $NEED_SUDO -eq 1 ] && [ "$(id -u)" -ne 0 ]; then
  echo -e "${YELLOW}Some checks require root access. For complete information, run with sudo.${RESET}\n"
fi

check_gpu_modules
echo ""
check_gpu_power
echo ""
check_display_server
echo ""
check_environment
echo ""
check_gl_info
echo ""
show_kernel_parameters
echo ""
check_dkms_status
echo ""
suggest_fixes
