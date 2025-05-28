#!/bin/bash

# sessionctl.sh - Root-only session launcher for Arch_OS
# Resides in /root and is used to start Wayland or X11 sessions

set -euo pipefail

# === Configuration ===
# Default user - override with env var SESSION_USER
USER="${SESSION_USER:-nikunj}"
TTY="$(tty)"
export XDG_VTNR="${TTY#/dev/tty}"
CONFIG_FILE="/etc/sessionctl.conf"

# Load config from file if it exists
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

# Check if script is run as root
if [[ $(id -u) -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

# Validate that user exists
if ! id "$USER" &>/dev/null; then
  echo "Error: User '$USER' does not exist."
  echo "Specify a valid user with SESSION_USER=username $0 <command>"
  exit 1
fi

# === Helper Functions ===

launch_wayland() {
  echo "Switching to user '$USER' and launching Plasma Wayland..."
  # Clean environment variables that might affect Wayland session
  exec su - "$USER" -c 'exec dbus-run-session startplasma-wayland'
}

launch_x11() {
  echo "Switching to user '$USER' and launching Plasma X11..."
  exec su - "$USER" -c 'exec startx'
}

launch_root_shell() {
  echo "Dropping into secure root shell..."
  exec /bin/bash
}

debug_info() {
  echo "=== Session Controller Debug Info ==="
  echo "User: $USER"
  echo "TTY: $TTY"
  echo "XDG_VTNR: $XDG_VTNR"
  echo "Config file: $CONFIG_FILE"
  
  echo -e "\n=== User and Group Info ==="
  id "$USER"
  
  echo -e "\n=== Display Server Status ==="
  systemctl status display-manager.service 2>/dev/null || echo "No display manager running"
  
  echo -e "\n=== Graphics Driver Status ==="
  lsmod | grep -E 'i915|nvidia' | sort
  
  echo -e "\n=== X11 Config ==="
  ls -la /etc/X11/xorg.conf.d/
  
  echo -e "\n=== User Environment ==="
  su - "$USER" -c 'printenv | grep -E "DISPLAY|WAYLAND|XDG|DBUS"'
}

create_config() {
  echo "Creating default configuration file at $CONFIG_FILE"
  cat > "$CONFIG_FILE" << EOF
# sessionctl configuration
# Override default user for session launching
USER="$USER"

# Uncomment and set to true to auto-restart session after crashes
#AUTO_RESTART="true"

# Uncomment to customize session commands
#WAYLAND_CMD="dbus-run-session startplasma-wayland"
#X11_CMD="startx"
EOF
  
  echo "Configuration file created. Edit $CONFIG_FILE to customize behavior."
}

usage() {
  echo "Usage: $0 {wayland|x11|root|debug|config}"
  echo "   or: SESSION_USER=username $0 <command>"
  echo
  echo "Commands:"
  echo "  wayland   Launch Plasma Wayland session as user"
  echo "  x11       Launch X11 session as user"
  echo "  root      Start a root shell"
  echo "  debug     Show debug information"
  echo "  config    Create default config file"
  exit 1
}

# === Main ===

case "${1:-}" in
  wayland) launch_wayland ;;
  x11)     launch_x11 ;;
  root)    launch_root_shell ;;
  debug)   debug_info ;;
  config)  create_config ;;
  *)       usage ;;
esac