#!/bin/bash

# Arch Linux UEFI Boot Manager Helper Script
# Utility functions for managing UEFI boot entries
# For diagnostics, creation, and backup of UEFI boot config

set -euo pipefail

# === UEFI Helper Functions ===

# Show all current boot entries
show_boot_entries() {
  efibootmgr -v
}

# Create a new boot entry for Arch Linux
create_arch_entry() {
  local esp_dev="${1:-/dev/nvme0n1p1}"           # Default ESP device
  local esp_path="${2:-/boot/efi}"               # Default mountpoint (unused)
  local label="${3:-Satyanet Arch-Linux}"        # Default label
  local loader="${4:-/EFI/Linux/arch-linux.efi}" # Default loader path

  echo "Creating UEFI boot entry for: $label"
  echo "  ESP device: $esp_dev"
  echo "  Loader: $loader"

  # Extract disk and partition number
  local disk_dev
  local part_num
  disk_dev=$(echo "$esp_dev" | sed 's/p[0-9]\+$//')
  part_num=$(echo "$esp_dev" | grep -o '[0-9]\+$')

  efibootmgr --create --disk "$disk_dev" --part "$part_num" \
    --label "$label" --loader "$loader"

  if [ $? -eq 0 ]; then
    echo "Boot entry created successfully."
    show_boot_entries
  else
    echo "Failed to create boot entry."
    return 1
  fi
}

# Create a boot entry for systemd-boot
add_systemd_boot_entry() {
  local esp_dev="${1:-/dev/nvme0n1p1}"
  local loader_path="${2:-/EFI/systemd/systemd-bootx64.efi}"
  local label="${3:-satyanet-boot}"

  local disk_dev
  local part_num
  disk_dev=$(echo "$esp_dev" | sed 's/p[0-9]\+$//')
  part_num=$(echo "$esp_dev" | grep -o '[0-9]\+$')

  echo "Adding UEFI boot entry for systemd-boot:"
  echo "  ESP device: $esp_dev"
  echo "  Loader path: $loader_path"
  echo "  Label: $label"

  efibootmgr --create \
    --disk "$disk_dev" \
    --part "$part_num" \
    --label "$label" \
    --loader "$loader_path"
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

# Install systemd-boot if not already installed
install_systemd_boot() {
  bootctl --path=/boot/efi install
}

# Show systemd-boot status
bootctl_status() {
  bootctl status
}

# === Script Usage ===
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <command> [args]"
  echo "Commands:"
  echo "  show_boot_entries                 - Display all UEFI boot entries"
  echo "  create_arch_entry [dev] [mnt] [label] [loader]   - Create boot entry for Arch Linux"
  echo "  add_systemd_boot_entry [dev] [loader] [label]    - Create boot entry for systemd-boot"
  echo "  delete_boot_entry NUM             - Delete boot entry by number"
  echo "  set_default_boot NUM              - Set default boot entry"
  echo "  backup_uefi_order                 - Backup UEFI boot configuration"
  echo "  install_systemd_boot              - Install systemd-boot bootloader"
  echo "  bootctl_status                    - Show systemd-boot status"
  exit 1
fi

# Execute the requested function with arguments
"$@"
