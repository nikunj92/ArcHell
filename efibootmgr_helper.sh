#!/bin/bash

# Arch Linux m18 UEFI Boot Manager Helper Script
# Provides utility functions for managing UEFI boot entries
# Intended for diagnostics, creation, and backup of UEFI boot config

set -euo pipefail

# === UEFI Helper Functions ===

# Show all current boot entries
show_boot_entries() {
  efibootmgr -v
}

# Create a new boot entry for Arch (using the correct drive configuration)
create_arch_entry() {
  local esp_dev="${1:-/dev/nvme0n1p1}"  # Default ESP location
  local esp_path="${2:-/boot/efi}"      # Default mountpoint
  local label="${3:-Arch Linux}"        # Default label
  local loader="${4:-/EFI/Linux/arch-linux.efi}"  # Default UKI path
  
  echo "Creating UEFI boot entry for $label"
  echo "  ESP device: $esp_dev"
  echo "  EFI loader: $loader"
  
  # Get disk part without partition number (for --disk parameter)
  local disk_dev=$(echo "$esp_dev" | sed 's/p[0-9]\+$//')
  local part_num=$(echo "$esp_dev" | grep -o '[0-9]\+$')
  
  efibootmgr --create --disk "$disk_dev" --part "$part_num" \
    --label "$label" --loader "$loader"
  
  if [ $? -eq 0 ]; then
    echo "Boot entry created successfully"
    show_boot_entries
  else
    echo "Failed to create boot entry"
    return 1
  fi
}

# Delete a boot entry by number (e.g., 0003)
delete_boot_entry() {
  local entry="$1"
  efibootmgr -b "$entry" -B
}

# Set default boot entry (by number)
set_default_boot() {
  local entry="$1"
  efibootmgr -o "$entry"
}

# Backup current UEFI entries
backup_uefi_order() {
  local backup_file="$HOME/efi_boot_order_backup-$(date +%Y%m%d-%H%M%S).txt"
  efibootmgr -v > "$backup_file"
  echo "Boot order backed up to $backup_file"
}

# Install systemd-boot if not already
install_systemd_boot() {
  bootctl --path=/boot/efi install
}

# Show bootctl status
  #bootctl status

# === Script Usage ===
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <command> [args]"
  echo "Commands:"
  echo "  show_boot_entries       - Display all UEFI boot entries"
  echo "  create_arch_entry       - Create boot entry for Arch Linux"
  echo "  delete_boot_entry NUM   - Delete boot entry by number"
  echo "  set_default_boot NUM    - Set default boot entry" 
  echo "  backup_uefi_order       - Backup UEFI boot configuration"
  echo "  install_systemd_boot    - Install systemd-boot bootloader"
  echo "  bootctl_status          - Show systemd-boot status"
  exit 1
fi

# Execute the requested function with arguments
"$@"