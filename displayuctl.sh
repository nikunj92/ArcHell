#!/bin/bash

# displayuctl.sh - Dynamic Display Layout Controller for Xorg and Wayland
# Supports automatic and manual layout switching for hybrid GPU setups.

set -euo pipefail

# === Configuration Presets ===

PRIMARY_INTERNAL="eDP-1"
PRIMARY_EXTERNAL="DP-1"
WAYLAND_INTERNAL="eDP-1"
WAYLAND_EXTERNAL="DP-1"

# === Detect Session Type ===
is_wayland() {
  [[ -n "${WAYLAND_DISPLAY:-}" ]] && return 0 || return 1
}

# === Detect connected outputs ===

connected_displays() {
  echo "Detecting connected displays..."
  
  if is_wayland; then
    # Use wlr-randr or kscreen-doctor for Wayland
    if command -v wlr-randr &>/dev/null; then
      echo "Using wlr-randr for Wayland detection:"
      wlr-randr
    elif command -v kscreen-doctor &>/dev/null; then
      echo "Using kscreen-doctor for KDE Wayland detection:"
      kscreen-doctor -o
    else
      echo "No Wayland display tool found (install wlr-randr or kscreen-doctor)"
      return 1
    fi
  else
    # Use xrandr for X11
    local outputs=$(xrandr | grep " connected " | cut -d ' ' -f1)
    
    if [[ -z "$outputs" ]]; then
      echo "No displays detected or xrandr failed."
      return 1
    fi
    
    echo "Connected displays (X11):"
    echo "$outputs" | while read -r display; do
      local res=$(xrandr | grep -A1 "^$display connected" | tail -n1 | awk '{print $1}')
      echo "  - $display ($res)"
    done
    
    # Check if external display is connected
    if echo "$outputs" | grep -q "$PRIMARY_EXTERNAL"; then
      echo "External display detected: $PRIMARY_EXTERNAL"
      return 0
    else
      echo "No external display detected."
      return 1
    fi
  fi
}

# === Layout Presets ===

# X11 display configuration functions
x11_internal_only() {
  xrandr --output "$PRIMARY_INTERNAL" --auto --primary
  xrandr --output "$PRIMARY_EXTERNAL" --off
  echo "X11 configuration applied: Internal Only"
}

x11_external_only() {
  if ! xrandr | grep -q "$PRIMARY_EXTERNAL connected"; then
    echo "Error: External display not connected!"
    return 1
  fi
  
  xrandr --output "$PRIMARY_EXTERNAL" --auto --primary
  xrandr --output "$PRIMARY_INTERNAL" --off
  echo "X11 configuration applied: External Only"
}

x11_dual() {
  if ! xrandr | grep -q "$PRIMARY_EXTERNAL connected"; then
    echo "Error: External display not connected!"
    return 1
  fi
  
  xrandr --output "$PRIMARY_EXTERNAL" --auto --primary
  xrandr --output "$PRIMARY_INTERNAL" --auto --right-of "$PRIMARY_EXTERNAL"
  echo "X11 configuration applied: Dual Mode"
}

# Wayland display configuration functions
wayland_config() {
  local mode="$1"
  
  if command -v kscreen-doctor &>/dev/null; then
    case "$mode" in
      internal)
        echo "Configuring KDE Wayland for internal-only display"
        kscreen-doctor output.$WAYLAND_EXTERNAL.disable output.$WAYLAND_INTERNAL.enable
        ;;
      external)
        echo "Configuring KDE Wayland for external-only display"
        kscreen-doctor output.$WAYLAND_INTERNAL.disable output.$WAYLAND_EXTERNAL.enable
        ;;
      dual)
        echo "Configuring KDE Wayland for dual display"
        kscreen-doctor output.$WAYLAND_INTERNAL.enable output.$WAYLAND_EXTERNAL.enable \
                      output.$WAYLAND_EXTERNAL.position.0,0 \
                      output.$WAYLAND_INTERNAL.position.1920,0
        ;;
      *)
        echo "Unknown Wayland mode: $mode"
        return 1
        ;;
    esac
    echo "Wayland configuration applied: $mode Mode"
  elif command -v wlr-randr &>/dev/null; then
    echo "wlr-randr support not implemented - please use the desktop environment's settings"
    return 1
  else
    echo "No supported Wayland display control tool found"
    return 1
  fi
}

# Unified interface functions
use_internal_only() {
  echo "Switching to internal display only..."
  
  if is_wayland; then
    wayland_config "internal"
  else
    x11_internal_only
  fi
}

use_external_only() {
  echo "Switching to external display only..."
  
  if is_wayland; then
    wayland_config "external"
  else
    x11_external_only
  fi
}

use_dual() {
  echo "Switching to dual display mode..."
  
  if is_wayland; then
    wayland_config "dual"
  else
    x11_dual
  fi
}

detect_and_apply() {
  echo "Auto-configuring display layout..."
  
  # In Wayland, always use dual mode if external display is connected
  if is_wayland; then
    if wlr-randr 2>/dev/null | grep -q "$WAYLAND_EXTERNAL" || \
       kscreen-doctor -o 2>/dev/null | grep -q "$WAYLAND_EXTERNAL"; then
      use_dual
    else
      use_internal_only
    fi
  # In X11, use regular detection
  else
    if xrandr | grep -q "$PRIMARY_EXTERNAL connected"; then
      use_dual
    else
      use_internal_only
    fi
  fi
}

status_info() {
  echo "Current display setup:"
  
  if is_wayland; then
    echo "Session type: Wayland"
    if command -v kscreen-doctor &>/dev/null; then
      kscreen-doctor -o
    elif command -v wlr-randr &>/dev/null; then
      wlr-randr
    else
      echo "No Wayland display tools found"
    fi
  else
    echo "Session type: X11"
    xrandr | grep -E "^[^ ]+ (connected|disconnected)"
    echo ""
    xrandr | grep -A1 "connected"
  fi
}

# === Help ===
usage() {
  echo "Usage: $0 [internal|external|dual|auto|status]"
  echo "  internal   - Only internal display active"
  echo "  external   - Only external display active"
  echo "  dual       - Extend internal + external"
  echo "  auto       - Auto detect and apply layout (default)"
  echo "  status     - Show current display info"
  exit 1
}

# === Entry Point ===

mode="${1:-auto}"

case "$mode" in
  internal) use_internal_only ;;
  external) use_external_only ;;
  dual)     use_dual ;;
  auto)     detect_and_apply ;;
  status)   status_info ;;
  *)        usage ;;
esac