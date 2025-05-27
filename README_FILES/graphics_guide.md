# Hybrid Graphics System on Arch Linux (Wayland First)

This guide explains the hybrid graphics system (Intel + NVIDIA) configured on this Arch Linux installation, with a primary focus on Wayland. It covers the configuration components, usage instructions, and the merits and drawbacks of this setup.

## System Overview

This Arch Linux installation uses a hybrid graphics setup with:

- **Intel integrated GPU** - Primary low-power display adapter
- **NVIDIA dedicated GPU** - High-performance GPU (e.g., RTX series)
- **Wayland as the primary display server** - With XWayland for X11 application compatibility
- **Dual display support** - Internal laptop display + external monitors
- **Both X11 and Wayland** - Support for both display server protocols

## Configuration Components

### 1. GPU Management

The system includes a dedicated GPU power management script (`gpumngrer.sh`) that can switch between power-saving (Intel-only) and performance (NVIDIA) modes. It integrates with power-profiles-daemon for system-wide power management.

### 2. Display Layout Management

A display control utility (`displayuctl.sh`) helps manage monitor configurations in both X11 and Wayland environments, supporting:
- Internal display only
- External display only
- Dual display (extended desktop)
- Auto-detect mode
- Status reporting

### 3. Session Management

The session controller (`sessionctl.sh`) provides a clean way to launch either:
- Plasma Wayland session
- Plasma X11 session
- Root shell (for maintenance)
- Debug mode (for troubleshooting)

### 4. X11 Configuration (Fallback/XWayland)

While Wayland is primary, XWayland allows X11 applications to run. Explicit X11 server configuration files (`10-modesetting.conf`, `10-nvidia-prime.conf`, `20-server-layout.conf`) are generally not needed for a Wayland session but are available for fallback or specific X11 session needs.

### 5. Wayland Configuration

For Wayland, environment variables are crucial for NVIDIA GPU support. These are typically defined in:
- System-wide: `/etc/environment.d/90-wayland-nvidia.conf` (created by `wayland-transition.sh`)
- User-specific: `~/.config/environment.d/99-wayland.conf` (from dotfiles)
Key variables include `GBM_BACKEND=nvidia-drm`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`, etc.

### 6. Diagnostic Tool

A unified system diagnostic tool (`hybrid-status.sh` or `hybrid-status-wayland.sh`) provides comprehensive information about:
- GPU module status
- Power management state
- Display server configuration
- Environment variables
- OpenGL renderer
- Kernel parameters
- Automatic problem detection and suggestions

## How to Use

### Switching Between Intel and NVIDIA GPUs

The `gpumngrer.sh` script controls GPU power states:

```bash
# Show current GPU power status
sudo gpumngrer.sh status

# Switch to Intel-only mode (better battery life)
sudo gpumngrer.sh intel

# Enable NVIDIA GPU (better performance)
sudo gpumngrer.sh nvidia

# Try to apply changes without full logout (Wayland only)
sudo gpumngrer.sh nvidia --apply

# Apply changes to current session
sudo gpumngrer.sh apply
```

For most changes, you'll need to log out and back in, but the `--apply` option attempts to reload the compositor for immediate application in Wayland sessions.

### Managing Display Layouts

The `displayuctl.sh` script handles multi-monitor configurations, primarily for Wayland (using `kscreen-doctor` or `wlr-randr`) and X11 as a fallback:

```bash
# Auto-detect and apply optimal layout
displayuctl.sh auto

# Use only internal laptop display
displayuctl.sh internal

# Use only external monitor
displayuctl.sh external

# Use both displays in extended mode
displayuctl.sh dual

# Show current display status
displayuctl.sh status
```

The script automatically detects whether you're using X11 or Wayland and applies the appropriate configuration method.

### Selecting Session Type

When logging in from a TTY, use the session controller (`sessionctl.sh`):

```bash
# For Wayland (recommended)
sudo sessionctl.sh wayland

# For X11 (fallback if Wayland has issues)
# sudo sessionctl.sh x11 
# (X11 session might require manual setup of /etc/X11/xorg.conf.d files if not using XWayland)

# For maintenance/troubleshooting
sudo sessionctl.sh root

# For diagnostics and environment information
sudo sessionctl.sh debug

# Create a configuration file
sudo sessionctl.sh config
```

You can customize the default user by setting the SESSION_USER environment variable:

```bash
sudo SESSION_USER=otheruser sessionctl.sh wayland
```

### System Diagnostics

The hybrid-status tool provides comprehensive information about my graphics setup:

```bash
# Run as regular user for basic info
hybrid-status.sh

# Run with sudo for complete information
sudo hybrid-status.sh
```

This will show module status, power management, environment variables, and suggest fixes for common issues.

### Making Permanent Changes

To permanently modify the graphics setup:

1. Wayland environment variables:
   - System: `/etc/environment.d/` (e.g., `90-wayland-nvidia.conf`)
   - User: `~/.config/environment.d/99_wayland.conf`
2. Kernel command line: `/etc/kernel/cmdline`
3. Initramfs configuration: `/etc/mkinitcpio.conf`
4. X11 configuration files (if using a dedicated X11 session): `/etc/X11/xorg.conf.d/`
5. Auto-starting configuration: `/etc/profile.d/arch_os_wayland.sh`
6. Session configuration is in `/etc/sessionctl.conf` (create with `sudo sessionctl.sh config`)

## Merits of This Setup

1. **Power Efficiency**
   - Intel GPU for daily tasks preserves battery life
   - NVIDIA GPU can be powered off when not needed
   - Integration with power-profiles-daemon for system-wide power management

2. **Performance When Needed**
   - Full NVIDIA GPU power available for gaming, ML, or content creation
   - Simple switching mechanism for different use cases

3. **Display Flexibility**
   - Support for multiple monitors with various configurations
   - Easy adaptation to different work environments
   - Works in both X11 and Wayland

4. **Compatibility**
   - Both X11 and Wayland support provides fallback options
   - Handles the complexities of NVIDIA on Wayland with proper environment variables
   - Advanced Wayland compatibility with G-SYNC, VRR support

5. **Automation**
   - Auto-starts preferred display server
   - Can auto-detect and configure displays
   - Some changes can be applied without logout

6. **Maintainability**
   - Modular configuration files
   - Well-commented configurations explain purpose and options
   - Built-in diagnostic tools

## Drawbacks and Challenges

1. **Complexity**: Hybrid graphics, especially with NVIDIA on Wayland, can still be complex.
2. **NVIDIA + Wayland Nuances**: While support has improved greatly, some applications or features might still have quirks. Environment variables and up-to-date drivers are key.
3. **Session Switching Overhead**: Major changes (like GPU mode via `gpumngrer.sh`) typically require a logout/login or reboot.
4. **Manual Intervention Required**: Some display configurations need manual switching
   - No seamless GPU switching like some vendor solutions (e.g., NVIDIA Optimus)

5. **Documentation Dependency**
   - Relies on good documentation (like this guide) for users to understand the system
   - Can be challenging to troubleshoot without documentation

## Troubleshooting

### Using the Diagnostic Tool

The quickest way to diagnose issues is to use the hybrid-status tool:

```bash
sudo hybrid-status.sh
```

This will automatically check for common problems and suggest fixes.

### X11 Issues (if running a dedicated X11 session)

1. Check that the Intel and NVIDIA modules are loaded:
   ```bash
   lsmod | grep -E 'i915|nvidia'
   ```

2. Verify X11 configuration in `/etc/X11/xorg.conf.d/`.
3. Check X11 logs for errors: `cat /var/log/Xorg.0.log | grep -E "EE|WW"`

### Wayland Issues

1. Verify environment variables are set (system-wide and user):
   ```bash
   printenv | grep -E 'NVIDIA|GBM|WLR|KWIN|LIBVA|GLX'
   ```
2. Check kernel command line: `cat /proc/cmdline` (look for `nvidia-drm.modeset=1`).
3. Check journal logs for Wayland/KWin/Compositor errors:
   ```bash
   journalctl -b | grep -E "kwin|wayland|plasma|mutter|nvidia"
   ```
4. Ensure `xorg-xwayland` is installed for X11 app compatibility.
5. For KDE Plasma Wayland, troubleshoot compositor:
   ```bash
   systemctl --user restart plasma-kwin_wayland.service
   ```

### GPU Power Management

1. Check PCI power management status:
   ```bash
   cat /sys/bus/pci/devices/0000:01:00.0/power/control
   ```

2. Verify if NVIDIA modules are loaded:
   ```bash
   lsmod | grep nvidia
   ```

3. Check power profiles:
   ```bash
   powerprofilesctl get
   ```

## Conclusion

This hybrid graphics setup provides a flexible and powerful environment for both power efficiency and performance. While it introduces some complexity, the included scripts help manage this complexity by providing simple command-line interfaces for common tasks and diagnostic tools to identify issues.

For day-to-day use, simply start with Wayland and use the auto-detection features, switching to performance mode only when needed for GPU-intensive tasks.
