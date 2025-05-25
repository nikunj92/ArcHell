#!/bin/bash

# Hybrid GPU Power Management for Intel/NVIDIA
# Controls power states and renders for better battery/performance balance

set -euo pipefail

# Check for root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# === Functions ===
status() {
  echo "=== GPU Power Status ==="
  
  # Intel GPU status
  echo "Intel GPU:"
  cat /sys/kernel/debug/dri/0/i915_runtime_pm_status || echo "Not available"
  
  # NVIDIA GPU status
  echo -e "\nNVIDIA GPU:"
  if lsmod | grep -q nvidia; then
    nvidia-smi -q -d POWER || echo "NVIDIA driver loaded but smi failed"
  else
    echo "NVIDIA driver not loaded"
  fi
  
  # PCIe runtime PM status for NVIDIA
  echo -e "\nNVIDIA PCIe power management:"
  cat /sys/bus/pci/devices/0000:01:00.0/power/control || echo "Not available"
}

intel_only() {
  echo "Switching to Intel-only mode (power saving)"
  
  # Unload NVIDIA modules
  modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia || true
  
  # Set PCIe power management to auto
  echo "auto" > /sys/bus/pci/devices/0000:01:00.0/power/control
  
  # Set environment for next login
  cat > /etc/environment.d/90-intel-gpu.conf << EOF
__GLX_VENDOR_LIBRARY_NAME=mesa
EOF
  
  echo "Done. You must logout and login for changes to take effect"
}

nvidia_on() {
  echo "Enabling NVIDIA GPU (performance mode)"
  
  # Set PCIe power management to on
  echo "on" > /sys/bus/pci/devices/0000:01:00.0/power/control
  
  # Load NVIDIA modules
  modprobe nvidia nvidia_uvm nvidia_modeset nvidia_drm
  
  # Set environment for next login
  cat > /etc/environment.d/90-intel-gpu.conf << EOF
__GLX_VENDOR_LIBRARY_NAME=nvidia
EOF
  
  echo "Done. You may need to logout and login for changes to take effect"
}

# === Main ===
case "${1:-status}" in
  status)
    status ;;
  intel)
    intel_only ;;
  nvidia)
    nvidia_on ;;
  *)
    echo "Usage: $0 {status|intel|nvidia}"
    echo "  status - Show current GPU power status"
    echo "  intel  - Switch to Intel-only mode (power saving)"
    echo "  nvidia - Enable NVIDIA GPU (performance mode)"
    ;;
esac