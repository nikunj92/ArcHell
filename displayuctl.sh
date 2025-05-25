#!/bin/bash

# displayuctl.sh - Dynamic Display Layout Controller for Xorg (CLI Fallback)
# Supports automatic and manual layout switching for hybrid GPU setups.

set -euo pipefail

# === Configuration Presets ===

PRIMARY_INTERNAL="eDP-1"
PRIMARY_EXTERNAL="DP-1"

# === Detect connected outputs ===

connected_displays() {
  echo "Detecting connected displays..."
  
  # Use xrandr to detect connected displays
  local outputs=$(xrandr | grep " connected " | cut -d ' ' -f1)
  
  if [[ -z "$outputs" ]]; then
    echo "No displays detected or xrandr failed."
    return 1
  fi
  
  echo "Connected displays:"
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
}

# === Layout Presets ===

use_internal_only() {
  echo "Switching to internal display only..."
  
  # Turn off external display and set internal as primary
  xrandr --output "$PRIMARY_INTERNAL" --auto --primary
  xrandr --output "$PRIMARY_EXTERNAL" --off
  
  echo "Display configuration applied: Internal Only"
}

use_external_only() {
  echo "Switching to external display only..."
  
  # Check if external display is connected
  if ! xrandr | grep -q "$PRIMARY_EXTERNAL connected"; then
    echo "Error: External display not connected!"
    return 1
  fi
  
  # Turn off internal display and set external as primary
  xrandr --output "$PRIMARY_EXTERNAL" --auto --primary
  xrandr --output "$PRIMARY_INTERNAL" --off
  
  echo "Display configuration applied: External Only"
}

use_dual() {
  echo "Switching to dual display mode..."
  
  # Check if external display is connected
  if ! xrandr | grep -q "$PRIMARY_EXTERNAL connected"; then
    echo "Error: External display not connected!"
    return 1
  fi
  
  # Set external as primary, position internal to the right
  xrandr --output "$PRIMARY_EXTERNAL" --auto --primary
  xrandr --output "$PRIMARY_INTERNAL" --auto --right-of "$PRIMARY_EXTERNAL"
  
  echo "Display configuration applied: Dual Mode"
}

detect_and_apply() {
  echo "Auto-configuring display layout..."
  
  # If external display is connected, use it as primary in dual mode
  if xrandr | grep -q "$PRIMARY_EXTERNAL connected"; then
    use_dual
  else
    # Fall back to internal only
    use_internal_only
  fi
}

# === Help ===
usage() {
  echo "Usage: $0 [internal|external|dual|auto]"
  echo "  internal   - Only internal display active"
  echo "  external   - Only external display active"
  echo "  dual       - Extend internal + external"
  echo "  auto       - Auto detect and apply layout (default)"
  exit 1
}

# === Entry Point ===

mode="${1:-auto}"

case "$mode" in
  internal) use_internal_only ;;
  external) use_external_only ;;
  dual)     use_dual ;;
  auto)     detect_and_apply ;;
  *)        usage ;;
esac