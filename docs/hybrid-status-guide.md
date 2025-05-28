# Hybrid Graphics Diagnostic Tool Guide

The `hybrid-status.sh` script provides comprehensive diagnostics for my hybrid Intel+NVIDIA graphics setup. This document explains how to use the tool and interpret its output.

## Overview

The hybrid-status tool performs a series of checks on my system's graphics configuration, reporting on:

- GPU kernel module status
- Power management configuration
- Display server and compositor information
- Graphics environment variables
- OpenGL renderer information
- Kernel parameters
- Automatic detection of common issues

The tool is designed to help you quickly diagnose problems with my hybrid graphics setup and provides targeted suggestions for fixing them.

## Usage

To run the tool with basic user permissions:

```bash
./hybrid-status.sh
```

For full diagnostics (recommended), run with sudo:

```bash
sudo ./hybrid-status.sh
```

## Understanding the Output

### GPU Modules Section

This section shows which graphics-related kernel modules are loaded:

```
Kernel GPU Modules
================
Intel i915:
  ✓ Loaded
  Usage: 3 dependent module(s)

NVIDIA modules:
  ✓ Base driver loaded
  ✓ nvidia_drm loaded
  ✓ nvidia_modeset loaded
  ✓ nvidia_uvm loaded
  ✓ KMS enabled
```

If you see "Not loaded" for a module that should be active, this indicates a potential issue.

### GPU Power Status Section

This section reveals power management information for both GPUs:

```
GPU Power Status
=============
Intel GPU power management:
  Runtime PM enabled, delay 10 ms
  Runtime status: active

NVIDIA GPU power management:
  PCIe power management: auto (power saving enabled)
  Current power state: active
```

For battery life, Intel should be active and NVIDIA in "suspended" state when not in use.

### Display Server Section

Shows which display server (X11 or Wayland) is active:

```
Display Server
===========
  ✓ Wayland session active (wayland-0)
  ✓ KWin Wayland compositor running
```

This helps verify that the expected display server is running.

### Graphics Environment Variables Section

Lists graphics-related environment variables that affect rendering and display:

```
Graphics Environment Variables
=========================
  ✓ __GLX_VENDOR_LIBRARY_NAME=nvidia
  ✓ GBM_BACKEND=nvidia-drm
  ✓ WLR_NO_HARDWARE_CURSORS=1
  ✓ LIBVA_DRIVER_NAME=nvidia
  ✓ __GL_GSYNC_ALLOWED=1
  ✗ KWIN_DRM_USE_MODIFIERS not set
```

Missing variables that should be set are marked with ✗.

### OpenGL Information Section

Shows which GPU is currently being used for OpenGL rendering:

```
OpenGL Information
===============
  OpenGL vendor: NVIDIA Corporation
  Renderer: NVIDIA GeForce RTX 4090/PCIe/SSE2
  Version: 4.6.0 NVIDIA 535.113.01
  ✓ Using NVIDIA GPU for OpenGL
```

This helps confirm if applications are using the expected GPU.

### Kernel Parameters Section

Displays the kernel parameters from `/proc/cmdline` and highlights important NVIDIA-related parameters:

```
Kernel Parameters
==============
  root=UUID=... rootflags=subvol=@ rw quiet splash nvidia-drm.modeset=1 nvidia-drm.fbdev=1
  
  ✓ nvidia-drm.modeset=1 (KMS enabled)
  ✓ nvidia-drm.fbdev=1 (Framebuffer enabled)
  ✗ nvidia.NVreg_PreserveVideoMemoryAllocations=1 not set
```

Missing recommended parameters are highlighted.

### Suggestions Section

Provides automatic recommendations based on detected issues:

```
Suggestions
=========
  ! NVIDIA module loaded but not used by Wayland
    → Check ~/.config/environment.d/99_wayland.conf is properly set
    
  ! Missing NVIDIA Prime configuration
    → Check if '/etc/X11/xorg.conf.d/10-nvidia-prime.conf' exists
```

These suggestions help you quickly identify and fix the most common problems.

## Troubleshooting Common Issues

### NVIDIA Not Used in Wayland

If you see "NVIDIA module loaded but not used by Wayland":

1. Check environment variables:
   ```bash
   cat ~/.config/environment.d/99_wayland.conf
   ```
   
2. Ensure it has at minimum:
   ```
   GBM_BACKEND=nvidia-drm
   __GLX_VENDOR_LIBRARY_NAME=nvidia
   WLR_NO_HARDWARE_CURSORS=1
   ```

3. Re-login or restart the compositor to apply changes.

### KMS Not Enabled for NVIDIA

If "NVIDIA module is loaded without KMS enabled":

1. Add `nvidia-drm.modeset=1` to kernel command line:
   ```bash
   sudo nano /etc/kernel/cmdline
   ```
   
2. Rebuild UKI:
   ```bash
   sudo mkinitcpio -p linux-uki
   ```

### Missing Configuration Files

If "Missing NVIDIA Prime configuration" or similar:

1. Check the referenced file location
2. Copy the appropriate file from dotfiles directory:
   ```bash
   sudo cp dotfiles/10-nvidia-prime.conf /etc/X11/xorg.conf.d/
   ```

## Conclusion

The hybrid-status tool is designed to make diagnosing graphics issues easier. Use it as the first step when troubleshooting display or performance problems, especially after system updates that might affect graphics drivers or configurations.

Run it periodically to ensure the hybrid graphics setup remains properly configured.
