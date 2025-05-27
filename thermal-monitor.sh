#!/bin/bash

# thermal-monitor.sh - System thermal monitoring dashboard
# Displays temperatures, fan status, and throttling information

set -euo pipefail

# Configuration
UPDATE_INTERVAL=2   # seconds
BAR_LENGTH=40
TEMP_WARNING=75     # yellow warning threshold
TEMP_CRITICAL=90    # red critical threshold
GPU_TEMP_WARNING=80
GPU_TEMP_CRITICAL=95

# Colors
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"
BOLD="\033[1m"

# Get CPU temperature
get_cpu_temp() {
  if command -v sensors >/dev/null; then
    # Try to get Core temperatures
    local temps=$(sensors | grep -E "Core [0-9]+:" | grep -oE "[0-9]+\.[0-9]+" | tr '\n' ' ')
    if [ -n "$temps" ]; then
      local max=$(echo "$temps" | tr ' ' '\n' | sort -nr | head -n1)
      echo "${max%.*}"
      return 0
    fi
  fi
  
  # Try Dell SMM hwmon
  local hwmon_dir=$(find /sys/devices/platform -path "*/dell_smm_hwmon/hwmon/hwmon*" -type d | head -n1)
  if [ -n "$hwmon_dir" ] && [ -f "$hwmon_dir/temp1_input" ]; then
    local temp=$(($(cat "$hwmon_dir/temp1_input") / 1000))
    echo "$temp"
    return 0
  fi
  
  # Fallback to generic temp
  if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    local temp=$(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))
    echo "$temp"
    return 0
  fi
  
  # No temperature found
  echo "N/A"
  return 1
}

# Get GPU temperature
get_gpu_temp() {
  if command -v nvidia-smi >/dev/null && nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null; then
    nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null
    return 0
  fi
  
  # Try sensors
  if command -v sensors >/dev/null; then
    local temp=$(sensors | grep -i "nvidia" | grep "temp" | grep -oE "[0-9]+\.[0-9]+" | head -n1)
    if [ -n "$temp" ]; then
      echo "${temp%.*}"
      return 0
    fi
  fi
  
  echo "N/A"
  return 1
}

# Get fan speed
get_fan_speed() {
  local hwmon_dir=$(find /sys/devices/platform -path "*/dell_smm_hwmon/hwmon/hwmon*" -type d | head -n1)
  
  if [ -n "$hwmon_dir" ] && [ -f "$hwmon_dir/pwm1" ]; then
    local mode=$(cat "$hwmon_dir/pwm1_enable" 2>/dev/null || echo "?")
    local speed=$(cat "$hwmon_dir/pwm1" 2>/dev/null || echo "0")
    local percent=$((speed * 100 / 255))
    
    if [ "$mode" = "0" ]; then
      echo "AUTO ($percent%)"
    else
      echo "$percent%"
    fi
    return 0
  fi
  
  # Try using sensors if we can
  if command -v sensors >/dev/null; then
    local fan=$(sensors | grep -i "fan" | grep -oE "[0-9]+ RPM" | head -n1)
    if [ -n "$fan" ]; then
      echo "$fan"
      return 0
    fi
  fi
  
  echo "N/A"
  return 1
}

# Check if CPU is throttling
is_cpu_throttling() {
  # Check for thermal throttling in dmesg
  if dmesg | grep -i "thermal" | grep -i "throttl" | tail -n1 | grep -q "$(date +%Y-%m-%d)"; then
    echo "YES"
    return 0
  fi
  
  if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
    local max_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq)
    local cur_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
    
    # If current frequency is significantly lower than max (25% or more)
    # and we're at high temperature, it's likely throttling
    local cpu_temp=$(get_cpu_temp)
    if [ "$cpu_temp" != "N/A" ] && [ "$cpu_temp" -gt 85 ]; then
      if [ "$cur_freq" -lt $((max_freq * 3 / 4)) ]; then
        echo "LIKELY"
        return 0
      fi
    fi
  fi
  
  echo "NO"
  return 1
}

# Get power consumption
get_power_consumption() {
  # For laptops with battery
  if [ -d /sys/class/power_supply/BAT0 ]; then
    if [ -f /sys/class/power_supply/BAT0/power_now ]; then
      local power=$(($(cat /sys/class/power_supply/BAT0/power_now) / 1000000))
      echo "$power W"
      return 0
    elif [ -f /sys/class/power_supply/BAT0/current_now ] && [ -f /sys/class/power_supply/BAT0/voltage_now ]; then
      local current=$(($(cat /sys/class/power_supply/BAT0/current_now)))
      local voltage=$(($(cat /sys/class/power_supply/BAT0/voltage_now)))
      local power=$((current * voltage / 1000000000000)) # Convert to watts
      echo "$power W"
      return 0
    fi
  fi
  
  # Try RAPL for Intel CPUs
  if [ -d /sys/class/powercap/intel-rapl ]; then
    local energy_uj=$(cat /sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj 2>/dev/null || echo "0")
    local power_uw=$(cat /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw 2>/dev/null || echo "0")
    
    if [ "$energy_uj" != "0" ] || [ "$power_uw" != "0" ]; then
      local power_w=$((power_uw / 1000000))
      echo "$power_w W (limit)"
      return 0
    fi
  fi
  
  echo "N/A"
  return 1
}

# Generate a colored temperature bar
temp_bar() {
  local temp="$1"
  local warning="$2"
  local critical="$3"
  
  if [ "$temp" = "N/A" ]; then
    echo "${BLUE}N/A${RESET}"
    return
  fi
  
  local bar_count=$((temp * BAR_LENGTH / 100))
  if [ "$bar_count" -gt "$BAR_LENGTH" ]; then
    bar_count=$BAR_LENGTH
  fi
  
  local color="$GREEN"
  if [ "$temp" -ge "$critical" ]; then
    color="$RED"
  elif [ "$temp" -ge "$warning" ]; then
    color="$YELLOW"
  fi
  
  local bar=$(printf "%${bar_count}s" | tr ' ' '█')
  local empty_space=$((BAR_LENGTH - bar_count))
  local empty_bar=$(printf "%${empty_space}s" | tr ' ' '░')
  
  echo -n "${color}${bar}${RESET}${empty_bar} ${color}${temp}°C${RESET}"
}

# Clear screen and display header
show_header() {
  clear
  echo -e "${BOLD}${CYAN}Alienware m18 Thermal Monitor${RESET}"
  echo -e "${CYAN}$(date)${RESET}"
  echo "Press Ctrl+C to exit"
  echo "----------------------------------------"
}

# Main monitoring function
monitor_loop() {
  while true; do
    show_header
    
    # CPU temperature
    local cpu_temp=$(get_cpu_temp)
    echo -e "${BOLD}CPU Temperature:${RESET} $(temp_bar "$cpu_temp" "$TEMP_WARNING" "$TEMP_CRITICAL")"
    
    # GPU temperature
    local gpu_temp=$(get_gpu_temp)
    echo -e "${BOLD}GPU Temperature:${RESET} $(temp_bar "$gpu_temp" "$GPU_TEMP_WARNING" "$GPU_TEMP_CRITICAL")"
    
    # Fan speed
    local fan_speed=$(get_fan_speed)
    echo -e "${BOLD}Fan Speed:      ${RESET} ${CYAN}${fan_speed}${RESET}"
    
    # Throttling status
    local throttling=$(is_cpu_throttling)
    case "$throttling" in
      "YES")
        echo -e "${BOLD}CPU Throttling:  ${RESET} ${RED}${throttling}${RESET}"
        ;;
      "LIKELY")
        echo -e "${BOLD}CPU Throttling:  ${RESET} ${YELLOW}${throttling}${RESET}"
        ;;
      *)
        echo -e "${BOLD}CPU Throttling:  ${RESET} ${GREEN}${throttling}${RESET}"
        ;;
    esac
    
    # Power consumption
    local power=$(get_power_consumption)
    echo -e "${BOLD}Power Draw:     ${RESET} ${BLUE}${power}${RESET}"
    
    # CPU frequencies
    if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
      echo -e "\n${BOLD}CPU Frequencies:${RESET}"
      
      # Group by physical CPU
      local cores=$(ls -d /sys/devices/system/cpu/cpu[0-9]* | wc -l)
      local physical_cores=$((cores / 2))  # Assuming Hyper-Threading
      
      # Show up to 6 cores to keep display reasonable
      local max_cores=6
      if [ "$physical_cores" -gt "$max_cores" ]; then
        physical_cores=$max_cores
      fi
      
      for ((i=0; i<physical_cores; i++)); do
        if [ -f /sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq ]; then
          local freq=$(($(cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq) / 1000))
          local max_freq=$(($(cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq) / 1000))
          local percent=$((freq * 100 / max_freq))
          
          local color="$GREEN"
          if [ "$percent" -lt 50 ]; then
            color="$BLUE"
          elif [ "$percent" -gt 90 ]; then
            color="$RED"
          elif [ "$percent" -gt 75 ]; then
            color="$YELLOW"
          fi
          
          printf "Core %-2d: ${color}%4d MHz${RESET} (%3d%%)\n" "$i" "$freq" "$percent"
        fi
      done
    fi
    
    # GPU utilization
    if command -v nvidia-smi >/dev/null; then
      echo -e "\n${BOLD}GPU Utilization:${RESET}"
      nvidia-smi --query-gpu=utilization.gpu,utilization.memory,memory.used,memory.total,clocks.current.graphics --format=csv,noheader,nounits 2>/dev/null | \
      while IFS=',' read -r gpu_util mem_util mem_used mem_total gpu_clock; do
        gpu_util=$(echo "$gpu_util" | tr -d ' ')
        mem_util=$(echo "$mem_util" | tr -d ' ')
        mem_used=$(echo "$mem_used" | tr -d ' ')
        mem_total=$(echo "$mem_total" | tr -d ' ')
        gpu_clock=$(echo "$gpu_clock" | tr -d ' ')
        
        local gpu_color="$GREEN"
        if [ "$gpu_util" -gt 90 ]; then
          gpu_color="$RED"
        elif [ "$gpu_util" -gt 75 ]; then
          gpu_color="$YELLOW"
        fi
        
        local mem_color="$GREEN"
        if [ "$mem_util" -gt 90 ]; then
          mem_color="$RED"
        elif [ "$mem_util" -gt 75 ]; then
          mem_color="$YELLOW"
        fi
        
        echo -e "GPU: ${gpu_color}${gpu_util}%${RESET} | Memory: ${mem_color}${mem_util}%${RESET} (${mem_used}MB / ${mem_total}MB) | Clock: ${gpu_clock}MHz"
      done
    fi
    
    sleep "$UPDATE_INTERVAL"
  done
}

# Check for necessary tools
check_dependencies() {
  local missing=0
  
  # Try to ensure lm_sensors is available
  if ! command -v sensors >/dev/null; then
    echo "Warning: 'sensors' command not found. Install lm_sensors for better temperature readings."
    echo "Run: sudo pacman -S lm_sensors"
    echo "Then: sudo sensors-detect --auto"
    missing=1
  fi
  
  if ! command -v nvidia-smi >/dev/null && lspci | grep -i nvidia >/dev/null; then
    echo "Warning: 'nvidia-smi' not found but NVIDIA GPU detected."
    echo "Install NVIDIA drivers for GPU monitoring."
    missing=1
  fi
  
  if [ "$missing" -eq 1 ]; then
    echo
    read -p "Continue anyway? [Y/n] " response
    if [[ "$response" =~ ^[Nn]$ ]]; then
      exit 1
    fi
    echo
  fi
}

# Main execution
check_dependencies
monitor_loop
