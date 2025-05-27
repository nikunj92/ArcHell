#!/bin/bash

# alienware-fan-control.sh - Fan control for Alienware m18 laptops
# Provides manual and automatic fan control modes

set -euo pipefail

# Configuration
DELL_SMM_MODULE="dell-smm-hwmon"
MODULE_PARAMS="restricted=0 ignore_dmi=1"
TEMP_PATH="/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon?"
FAN_SPEEDS=(0 1 2 3 4 5)  # 0=off, 5=max
PROFILES=(
  "quiet:2:75:3:85:4:95"    # Quiet: fan_speed:temp_threshold pairs
  "balanced:2:65:3:75:4:85:5:95"  # Balanced
  "performance:3:55:4:65:5:75"    # Performance (aggressive cooling)
  "max:5:0"                 # Always maximum
)
CURRENT_PROFILE="balanced"
CONFIG_DIR="$HOME/.config/alienware-fan"
CONFIG_FILE="$CONFIG_DIR/config"

# Root check
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR" 2>/dev/null || true
touch "$CONFIG_FILE" 2>/dev/null || true

# Load configuration if exists
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
fi

# Ensure kernel module is loaded with proper parameters
load_module() {
  if ! lsmod | grep -q "$DELL_SMM_MODULE"; then
    echo "Loading $DELL_SMM_MODULE with parameters: $MODULE_PARAMS"
    modprobe "$DELL_SMM_MODULE" $MODULE_PARAMS
    
    if ! lsmod | grep -q "$DELL_SMM_MODULE"; then
      echo "Failed to load $DELL_SMM_MODULE module. Aborting."
      exit 1
    fi
  else
    echo "$DELL_SMM_MODULE already loaded"
  fi
  
  # Check for hwmon device
  if ! find /sys/devices/platform -name "dell_smm_hwmon" >/dev/null; then
    echo "Dell SMM hwmon device not found. Module may not be properly initialized."
    echo "Try manually: sudo modprobe $DELL_SMM_MODULE $MODULE_PARAMS"
    exit 1
  fi
}

# Get current CPU temperature (highest core)
get_cpu_temp() {
  local temp=0
  
  # First try from dell_smm_hwmon
  if [ -f "$TEMP_PATH/temp1_input" ]; then
    temp=$(cat "$TEMP_PATH/temp1_input" 2>/dev/null || echo 0)
    temp=$((temp / 1000)) # Convert from milli-Celsius to Celsius
    echo "$temp"
    return
  fi
  
  # Fallback to sensors
  if command -v sensors >/dev/null; then
    temp=$(sensors | grep -i "Core" | awk '{print $3}' | sed 's/[^0-9.]//g' | sort -nr | head -n1 | cut -d. -f1)
    echo "${temp:-0}"
    return
  fi
  
  # Fallback to /proc/acpi/ibm/thermal (less likely on Alienware)
  if [ -f /proc/acpi/ibm/thermal ]; then
    temp=$(cat /proc/acpi/ibm/thermal | awk '{print $2}')
    echo "${temp:-0}"
    return
  fi
  
  # Last resort
  echo "0"
}

# Set fan speed (0-5)
set_fan_speed() {
  local speed=$1
  
  if ! [[ "$speed" =~ ^[0-5]$ ]]; then
    echo "Invalid fan speed: $speed (must be 0-5)"
    return 1
  fi
  
  if [ ! -f "$TEMP_PATH/pwm1_enable" ]; then
    echo "Fan control device not found at $TEMP_PATH"
    find /sys/devices/platform -name "dell_smm_hwmon" -type d
    exit 1
  fi
  
  # Enable manual control
  echo 1 > "$TEMP_PATH/pwm1_enable"
  
  # Set speed (scale from 0-5 to 0-255)
  local pwm_value=$((speed * 51))
  echo "$pwm_value" > "$TEMP_PATH/pwm1"
  echo "Fan speed set to $speed (PWM: $pwm_value)"
}

# Enable automatic control based on BIOS settings
enable_auto_control() {
  if [ -f "$TEMP_PATH/pwm1_enable" ]; then
    echo 0 > "$TEMP_PATH/pwm1_enable"
    echo "Fan control returned to automatic (BIOS) mode"
  fi
}

# Find the location of hwmon directory
find_hwmon_path() {
  TEMP_PATH=$(find /sys/devices/platform -path "*/dell_smm_hwmon/hwmon/hwmon*" -type d | head -n1)
  
  if [ -z "$TEMP_PATH" ]; then
    echo "Could not find hwmon path. Is dell_smm_hwmon loaded?"
    exit 1
  fi
  
  echo "Found hwmon path: $TEMP_PATH"
}

# Run the fan control in intelligent auto-adjusting mode
run_intelligent_mode() {
  local profile=$1
  local profile_data=""
  
  # Find the profile data
  for p in "${PROFILES[@]}"; do
    if [[ "$p" == "$profile:"* ]]; then
      profile_data=$p
      break
    fi
  done
  
  if [ -z "$profile_data" ]; then
    echo "Profile not found: $profile"
    echo "Available profiles: ${PROFILES[*]}"
    exit 1
  fi
  
  echo "Running intelligent fan control with profile: $profile"
  echo "Press Ctrl+C to exit"
  
  # Parse profile data into arrays
  local speeds=()
  local temps=()
  IFS=":" read -ra parts <<< "$profile_data"
  
  # Skip the first part (profile name)
  for ((i=1; i<${#parts[@]}; i+=2)); do
    if ((i+1 < ${#parts[@]})); then
      speeds+=("${parts[i]}")
      temps+=("${parts[i+1]}")
    fi
  done
  
  # Main loop
  while true; do
    local current_temp=$(get_cpu_temp)
    local target_speed=${speeds[0]}  # Default to lowest speed
    
    # Find appropriate speed for current temperature
    for ((i=0; i<${#temps[@]}; i++)); do
      if ((current_temp >= temps[i])); then
        target_speed=${speeds[i]}
      fi
    done
    
    # Apply the speed
    set_fan_speed "$target_speed"
    
    echo -ne "Temperature: ${current_temp}°C | Fan Speed: ${target_speed}/5 | Profile: ${profile}    \r"
    sleep 3
  done
}

# Show the current status
show_status() {
  local temp=$(get_cpu_temp)
  echo "Alienware Fan Control Status"
  echo "============================"
  echo "Kernel module: $(lsmod | grep -q "$DELL_SMM_MODULE" && echo "Loaded" || echo "Not loaded")"
  echo "Fan control available: $([ -f "$TEMP_PATH/pwm1_enable" ] && echo "Yes" || echo "No")"
  
  if [ -f "$TEMP_PATH/pwm1_enable" ]; then
    local mode=$(cat "$TEMP_PATH/pwm1_enable")
    if [ "$mode" == "0" ]; then
      echo "Control mode: Automatic (BIOS)"
    else
      echo "Control mode: Manual"
      local pwm=$(cat "$TEMP_PATH/pwm1" 2>/dev/null || echo "Unknown")
      local speed=$((pwm / 51))
      echo "Current PWM: $pwm (Speed ~$speed/5)"
    fi
  fi
  
  echo "Current temperature: ${temp}°C"
  echo "Selected profile: $CURRENT_PROFILE"
  echo
  echo "Available profiles:"
  for p in "${PROFILES[@]}"; do
    local pname=${p%%:*}
    echo "  - $pname"
  done
}

# Save current configuration
save_config() {
  cat > "$CONFIG_FILE" << EOF
# Alienware Fan Control Configuration
CURRENT_PROFILE="$CURRENT_PROFILE"
EOF
  echo "Configuration saved to $CONFIG_FILE"
}

# Show help
show_help() {
  echo "Alienware Fan Control for m18"
  echo "Usage: $0 [command]"
  echo
  echo "Commands:"
  echo "  status          Show current status"
  echo "  auto            Return fan control to BIOS (default)"
  echo "  set <speed>     Set fan speed manually (0-5)"
  echo "  monitor         Show real-time temperature monitor"
  echo "  start           Start intelligent fan control with current profile"
  echo "  profile <name>  Set profile (quiet, balanced, performance, max)"
  echo "  install         Configure for automatic startup"
  echo "  help            Show this help"
  echo
  echo "To run in intelligent mode with balanced profile:"
  echo "  $0 profile balanced && $0 start"
}

# Setup service for automatic startup
install_service() {
  cat > /etc/systemd/system/alienware-fan-control.service << EOF
[Unit]
Description=Alienware Fan Control Service
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/alienware-fan-control.sh start
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

  # Copy script to system location
  cp "$0" /usr/local/bin/alienware-fan-control.sh
  chmod +x /usr/local/bin/alienware-fan-control.sh

  # Reload systemd and enable the service
  systemctl daemon-reload
  systemctl enable alienware-fan-control.service
  
  # Create module loader
  cat > /etc/modules-load.d/dell-smm-hwmon.conf << EOF
# Load Dell SMM hwmon module
dell-smm-hwmon
EOF

  # Create module parameters
  cat > /etc/modprobe.d/dell-smm-hwmon.conf << EOF
# Dell SMM hwmon module parameters
options dell-smm-hwmon restricted=0 ignore_dmi=1
EOF

  echo "Installation complete. Service configured to start at boot."
  echo "Start now with: systemctl start alienware-fan-control"
}

# Temperature monitor
show_temp_monitor() {
  echo "Temperature Monitor (Press Ctrl+C to exit)"
  echo "----------------------------------------"
  
  while true; do
    local temp=$(get_cpu_temp)
    local bar=$(printf '█%.0s' $(seq 1 $((temp / 5))))
    
    # Color based on temperature
    if [ "$temp" -lt 60 ]; then
      color="\033[32m" # Green
    elif [ "$temp" -lt 80 ]; then
      color="\033[33m" # Yellow
    else
      color="\033[31m" # Red
    fi
    
    echo -ne "CPU: ${color}${temp}°C ${bar}\033[0m         \r"
    sleep 1
  done
}

# Main
case "${1:-help}" in
  status)
    load_module
    find_hwmon_path
    show_status
    ;;
  auto)
    load_module
    find_hwmon_path
    enable_auto_control
    ;;
  set)
    if [ -z "${2:-}" ]; then
      echo "Error: No speed specified. Use 0-5."
      exit 1
    fi
    load_module
    find_hwmon_path
    set_fan_speed "$2"
    ;;
  start)
    load_module
    find_hwmon_path
    run_intelligent_mode "$CURRENT_PROFILE"
    ;;
  profile)
    if [ -z "${2:-}" ]; then
      echo "Error: No profile specified."
      echo "Available profiles: quiet, balanced, performance, max"
      exit 1
    fi
    CURRENT_PROFILE="$2"
    save_config
    echo "Profile set to: $CURRENT_PROFILE"
    echo "Start fan control with: $0 start"
    ;;
  monitor)
    show_temp_monitor
    ;;
  install)
    install_service
    ;;
  help|*)
    show_help
    ;;
esac
