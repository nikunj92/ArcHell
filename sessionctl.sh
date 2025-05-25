#!/bin/bash

# sessionctl.sh - Root-only session launcher for Arch_OS
# Resides in /root and is used to start Wayland or X11 sessions as user 'nikunj'

set -euo pipefail

# === Configuration ===
USER="nikunj"
TTY="$(tty)"
export XDG_VTNR="${TTY#/dev/tty}"

# Check if script is run as root
if [[ $(id -u) -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

# === Helper Functions ===

launch_wayland() {
  echo "Switching to user '$USER' and launching Plasma Wayland..."
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

usage() {
  echo "Usage: $0 {wayland|x11|root}"
  exit 1
}

# === Main ===

case "${1:-}" in
  wayland) launch_wayland ;;
  x11)     launch_x11 ;;
  root)    launch_root_shell ;;
  *)       usage ;;
esac