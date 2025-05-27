#!/bin/bash

# graphics-backup.sh - Targeted backup for graphics configuration
# Creates snapshots specifically focused on graphics configuration

set -euo pipefail

# Configuration
SNAPSHOT_DIR="/.snapshots"
GRAPHICS_BACKUP_PREFIX="graphics-working"
GRAPHICS_BACKUP_DIRS=(
  "/etc/X11/xorg.conf.d"
  "/etc/modprobe.d"
  "/etc/mkinitcpio.conf"
  "/etc/kernel/cmdline"
  "/boot/efi/loader/entries"
  "/boot/efi/EFI/Linux"
  "/home/$USER/.config/environment.d"
)
CONFIG_BACKUP_DIR="/sacredData/graphics-backup-$(date +%Y%m%d)"
BTRFS_SNAPSHOT_NAME="$GRAPHICS_BACKUP_PREFIX-$(date +%Y%m%d-%H%M)"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Function to create a full btrfs snapshot
create_btrfs_snapshot() {
  echo "Creating btrfs system snapshot named '${BTRFS_SNAPSHOT_NAME}'..."
  
  if [[ ! -d "$SNAPSHOT_DIR" ]]; then
    echo "Error: Snapshot directory does not exist: $SNAPSHOT_DIR"
    exit 1
  fi
  
  # Check if we're on btrfs
  if ! mount | grep "on / type btrfs" > /dev/null; then
    echo "Error: Root filesystem is not btrfs"
    exit 1
  fi
  
  # Create read-only snapshot
  btrfs subvolume snapshot -r / "${SNAPSHOT_DIR}/${BTRFS_SNAPSHOT_NAME}"
  
  echo "Snapshot created at: ${SNAPSHOT_DIR}/${BTRFS_SNAPSHOT_NAME}"
  echo "To restore system to this state, you can use:"
  echo "  1. Boot from live USB"
  echo "  2. Mount your partitions (see mounter.sh)"
  echo "  3. Use: btrfs subvolume delete /mnt/@"
  echo "  4. Use: btrfs subvolume snapshot \"${SNAPSHOT_DIR}/${BTRFS_SNAPSHOT_NAME}\" /mnt/@"
}

# Function to backup specific config files
backup_config_files() {
  echo "Backing up graphics configuration files..."
  
  # Create backup directory
  mkdir -p "$CONFIG_BACKUP_DIR"
  
  # Backup each directory
  for dir in "${GRAPHICS_BACKUP_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
      target_dir="${CONFIG_BACKUP_DIR}${dir}"
      mkdir -p "$(dirname "$target_dir")"
      cp -r "$dir" "$(dirname "$target_dir")"
      echo "Backed up: $dir"
    else
      echo "Warning: Directory not found: $dir"
    fi
  done
  
  # Backup specific script files
  echo "Backing up graphics management scripts..."
  cp "/usr/local/bin/hybrid-status.sh" "$CONFIG_BACKUP_DIR/" 2>/dev/null || true
  cp "/usr/local/bin/gpumngrer.sh" "$CONFIG_BACKUP_DIR/" 2>/dev/null || true
  cp "/usr/local/bin/displayuctl.sh" "$CONFIG_BACKUP_DIR/" 2>/dev/null || true
  
  # Save GPU module status
  echo "Capturing current GPU module status..."
  lsmod | grep -E "i915|nvidia" > "$CONFIG_BACKUP_DIR/gpu_modules.txt"
  
  # Store current package list
  echo "Storing graphics-related package list..."
  pacman -Q | grep -E "nvidia|mesa|xorg|wayland|kwin|plasma" > "$CONFIG_BACKUP_DIR/graphics_packages.txt"
  
  # Store kernel parameters
  echo "Storing kernel parameters..."
  cat /proc/cmdline > "$CONFIG_BACKUP_DIR/kernel_cmdline.txt"
  
  echo "Configuration backup complete at: $CONFIG_BACKUP_DIR"
}

# Function to create restore script
create_restore_script() {
  local restore_script="$CONFIG_BACKUP_DIR/restore_graphics.sh"
  
  cat > "$restore_script" << 'EOF'
#!/bin/bash
# Restore script for graphics configuration

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "Restoring graphics configuration..."

# Restore configuration directories
for dir in "$SCRIPT_DIR"/*/ ; do
  if [[ -d "$dir" && "$dir" != "$SCRIPT_DIR//" ]]; then
    target_dir="/${dir#$SCRIPT_DIR/}"
    echo "Restoring: $target_dir"
    mkdir -p "$(dirname "$target_dir")"
    cp -r "$dir" "$(dirname "$target_dir")"
  fi
done

# Restore individual scripts
for script in hybrid-status.sh gpumngrer.sh displayuctl.sh; do
  if [[ -f "$SCRIPT_DIR/$script" ]]; then
    echo "Restoring script: $script"
    cp "$SCRIPT_DIR/$script" /usr/local/bin/
    chmod +x "/usr/local/bin/$script"
  fi
done

echo "Rebuilding initramfs with restored configuration..."
mkinitcpio -P

echo "Restoration complete. Please reboot to apply changes."
EOF

  chmod +x "$restore_script"
  echo "Created restore script: $restore_script"
}

# Function to show free disk space
show_space_info() {
  echo "Checking available disk space..."
  df -h / /.snapshots
  
  # Count existing backups
  if [[ -d "$SNAPSHOT_DIR" ]]; then
    local backup_count=$(find "$SNAPSHOT_DIR" -maxdepth 1 -name "$GRAPHICS_BACKUP_PREFIX*" | wc -l)
    echo "Existing graphics backups: $backup_count"
  fi
}

# Main function
main() {
  local create_snapshot=true
  local backup_config=true
  
  case "${1:-all}" in
    snapshot)
      backup_config=false
      ;;
    config)
      create_snapshot=false
      ;;
    space)
      show_space_info
      exit 0
      ;;
    list)
      echo "Existing graphics snapshots:"
      find "$SNAPSHOT_DIR" -maxdepth 1 -name "$GRAPHICS_BACKUP_PREFIX*" -exec ls -lah {} \;
      exit 0
      ;;
    all)
      # Default: do both
      ;;
    restore)
      echo "Please use a specific restore script from a backup directory"
      echo "Example: /sacredData/graphics-backup-YYYYMMDD/restore_graphics.sh"
      exit 1
      ;;
    help|--help)
      echo "Graphics Backup Tool for Arch Linux"
      echo "Usage: $0 [command]"
      echo
      echo "Commands:"
      echo "  all       Create both snapshot and config backup (default)"
      echo "  snapshot  Create only btrfs snapshot"
      echo "  config    Backup only config files"
      echo "  space     Show available disk space"
      echo "  list      List existing graphics backups"
      echo "  help      Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown command: $1"
      echo "Use '$0 help' for usage information"
      exit 1
      ;;
  esac
  
  echo "=== Graphics Backup Tool ==="
  show_space_info
  
  if [[ "$create_snapshot" == true ]]; then
    create_btrfs_snapshot
  fi
  
  if [[ "$backup_config" == true ]]; then
    backup_config_files
    create_restore_script
  fi
  
  echo "Backup operation completed successfully."
}

main "$@"
