#!/bin/bash

# dotfiles_manager.sh - Dotfiles backup and deployment manager
# Manages dotfiles between system locations and repository

set -euo pipefail

# Repository location (where dotfiles are stored)
REPO_DIR="$(dirname "$(realpath "$0")")"
DOTFILES_DIR="${REPO_DIR}/dotfiles"
BACKUP_DIR="${REPO_DIR}/backups/$(date +%Y%m%d-%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Define mappings between repository files and system locations
declare -A FILE_MAPPINGS=(
  # Bootloader files
  ["loader.conf"]="/boot/efi/loader/loader.conf"
  ["satyanet.conf"]="/boot/efi/loader/entries/satyanet.conf"
  ["satyanet-fallback.conf"]="/boot/efi/loader/entries/satyanet-fallback.conf" 
  ["satyanet-no-uki.conf"]="/boot/efi/loader/entries/satyanet-default.conf"
  ["windows.conf"]="/boot/efi/loader/entries/windows.conf"
  
  # System configuration
  ["mkinitcpio.conf"]="/etc/mkinitcpio.conf"
  ["linux-uki.preset"]="/etc/mkinitcpio.d/linux-uki.preset"
  ["cmdline"]="/etc/kernel/cmdline"
  ["vconsole.conf"]="/etc/vconsole.conf"
  ["blacklist.conf"]="/etc/modprobe.d/blacklist.conf"
  ["arch_os_wayland.sh"]="/etc/profile.d/arch_os_wayland.sh" # TODO: This script might need review for Wayland-only
  
  # X11/Graphics configuration
  # These are X11 server specific. For a Wayland-first setup, they might not be needed.
  # XWayland will handle X11 applications without these usually.
  # ["10-modesetting.conf"]="/etc/X11/xorg.conf.d/10-modesetting.conf"
  # ["10-nvidia-prime.conf"]="/etc/X11/xorg.conf.d/10-nvidia-prime.conf"
  # ["20-server-layout.conf"]="/etc/X11/xorg.conf.d/20-server-layout.conf"
  ["99-wayland.conf"]="${HOME}/.config/environment.d/99_wayland.conf" # User-specific Wayland env vars
  
  # Shell configuration
  [".bashrc"]="${HOME}/.bashrc"
)

# Print a colored message
print_msg() {
  local color="$1"
  local msg="$2"
  echo -e "${color}${msg}${NC}"
}

# Safely copy a file, using sudo if necessary
safe_copy() {
  local src="$1"
  local dst="$2"
  
  # Create parent directory if it doesn't exist
  local dst_dir=$(dirname "$dst")
  if [[ ! -d "$dst_dir" ]]; then
    if [[ "$dst_dir" == /boot/* || "$dst_dir" == /etc/* ]]; then
      sudo mkdir -p "$dst_dir"
    else
      mkdir -p "$dst_dir"
    fi
  fi
  
  # Copy the file, using sudo if needed
  if [[ -w "$dst_dir" ]]; then
    cp -f "$src" "$dst"
  else
    sudo cp -f "$src" "$dst"
  fi
  
  return $?
}

# Backup a single file from system to repo
backup_file() {
  local repo_file="$1"
  local system_file="${FILE_MAPPINGS[$repo_file]}"
  local target_file="${DOTFILES_DIR}/${repo_file}"
  
  # Check if system file exists
  if [[ ! -f "$system_file" ]]; then
    print_msg "$YELLOW" "Warning: System file not found: $system_file"
    return 1
  fi
  
  # Create directory structure if needed
  mkdir -p "$(dirname "$target_file")"
  
  # Copy file with sudo if needed
  if [[ -r "$system_file" ]]; then
    cp -f "$system_file" "$target_file"
  else
    sudo cp -f "$system_file" "$target_file"
  fi
  
  if [[ $? -eq 0 ]]; then
    print_msg "$GREEN" "Backed up: $system_file → $target_file"
    return 0
  else
    print_msg "$RED" "Failed to backup: $system_file"
    return 1
  fi
}

# Deploy a single file from repo to system
deploy_file() {
  local repo_file="$1"
  local system_file="${FILE_MAPPINGS[$repo_file]}"
  local source_file="${DOTFILES_DIR}/${repo_file}"
  
  # Check if repo file exists
  if [[ ! -f "$source_file" ]]; then
    print_msg "$YELLOW" "Warning: Repository file not found: $source_file"
    return 1
  fi
  
  # Copy file with safe_copy helper
  if safe_copy "$source_file" "$system_file"; then
    print_msg "$GREEN" "Deployed: $source_file → $system_file"
    return 0
  else
    print_msg "$RED" "Failed to deploy: $source_file → $system_file"
    return 1
  fi
}

# Backup all dotfiles from system to repo
backup_all() {
  print_msg "$BLUE" "Backing up all dotfiles to repository..."
  
  local success=0
  local failed=0
  
  for file in "${!FILE_MAPPINGS[@]}"; do
    if backup_file "$file"; then
      ((success++))
    else
      ((failed++))
    fi
  done
  
  print_msg "$GREEN" "Backup complete: $success files succeeded, $failed files failed"
}

# Deploy all dotfiles from repo to system
deploy_all() {
  print_msg "$BLUE" "Deploying all dotfiles to system..."
  
  local success=0
  local failed=0
  
  for file in "${!FILE_MAPPINGS[@]}"; do
    if deploy_file "$file"; then
      ((success++))
    else
      ((failed++))
    fi
  done
  
  print_msg "$GREEN" "Deployment complete: $success files succeeded, $failed files failed"
}

# Create a timestamped backup of system files to backup directory
create_backup() {
  print_msg "$BLUE" "Creating full backup of system dotfiles..."
  
  mkdir -p "$BACKUP_DIR"
  
  for file in "${!FILE_MAPPINGS[@]}"; do
    local system_file="${FILE_MAPPINGS[$file]}"
    local repo_name="$file"
    local backup_file="${BACKUP_DIR}/${repo_name}"
    
    if [[ -f "$system_file" ]]; then
      # Create directory structure if needed
      mkdir -p "$(dirname "$backup_file")"
      
      if [[ -r "$system_file" ]]; then
        cp -f "$system_file" "$backup_file"
      else
        sudo cp -f "$system_file" "$backup_file"
      fi
      
      if [[ $? -eq 0 ]]; then
        print_msg "$GREEN" "Backed up: $system_file → $backup_file"
      else
        print_msg "$RED" "Failed to backup: $system_file"
      fi
    else
      print_msg "$YELLOW" "Skip: $system_file (not found)"
    fi
  done
  
  print_msg "$GREEN" "Full backup created at: $BACKUP_DIR"
}

# Git operations - commit and push changes
git_push() {
  local commit_msg="${1:-Auto-update dotfiles}"
  
  if [[ ! -d "$REPO_DIR/.git" ]]; then
    print_msg "$RED" "Error: Not a git repository. Initialize first with: git init"
    return 1
  fi
  
  # Check if there are changes
  if ! git -C "$REPO_DIR" status --porcelain | grep -q .; then
    print_msg "$YELLOW" "No changes to commit"
    return 0
  fi
  
  print_msg "$BLUE" "Committing changes to git repository..."
  git -C "$REPO_DIR" add "$DOTFILES_DIR"
  git -C "$REPO_DIR" commit -m "$commit_msg"
  
  print_msg "$BLUE" "Pushing changes to remote repository..."
  if git -C "$REPO_DIR" remote | grep -q .; then
    git -C "$REPO_DIR" push
    print_msg "$GREEN" "Changes pushed successfully"
  else
    print_msg "$YELLOW" "No remote repository configured. Changes committed locally only."
    print_msg "$YELLOW" "To push, add a remote with: git remote add origin <url>"
  fi
}

# List all managed files with their status
list_files() {
  print_msg "$BLUE" "Managed dotfiles:"
  printf "%-30s %-40s %s\n" "Repository File" "System Location" "Status"
  echo "------------------------------------------------------------------------------"
  
  for file in "${!FILE_MAPPINGS[@]}"; do
    local system_file="${FILE_MAPPINGS[$file]}"
    local repo_file="${DOTFILES_DIR}/${file}"
    local status=""
    
    if [[ -f "$system_file" ]]; then
      if [[ -f "$repo_file" ]]; then
        status="${GREEN}[BOTH]${NC}"
      else
        status="${YELLOW}[SYSTEM ONLY]${NC}"
      fi
    else
      if [[ -f "$repo_file" ]]; then
        status="${BLUE}[REPO ONLY]${NC}"
      else
        status="${RED}[MISSING]${NC}"
      fi
    fi
    
    printf "%-30s %-40s %s\n" "$file" "$system_file" "$status"
  done
}

# Display usage information
show_help() {
  cat << EOF
Dotfiles Manager - Backup, deploy, and manage dotfiles

Usage: $(basename "$0") <command> [options]

Commands:
  backup [file]       Backup dotfiles from system to repository
                      Specify a file name to backup just that file
  deploy [file]       Deploy dotfiles from repository to system
                      Specify a file name to deploy just that file
  create-backup       Create a timestamped backup of system dotfiles
  push [commit-msg]   Commit and push changes to git repository
  list                List all managed dotfiles and their status
  help                Show this help message

Examples:
  $(basename "$0") backup              # Backup all dotfiles from system
  $(basename "$0") backup .bashrc      # Backup only .bashrc
  $(basename "$0") deploy              # Deploy all dotfiles to system
  $(basename "$0") deploy mkinitcpio.conf  # Deploy only mkinitcpio.conf
  $(basename "$0") create-backup       # Create a timestamped backup
  $(basename "$0") push "Updated configs"  # Commit and push changes
  $(basename "$0") list                # List all managed files

EOF
}

# Main entrypoint
main() {
  local cmd="${1:-help}"
  shift 2>/dev/null || true
  
  case "$cmd" in
    backup)
      if [[ -n "${1:-}" ]]; then
        if [[ -v "FILE_MAPPINGS[$1]" ]]; then
          backup_file "$1"
        else
          print_msg "$RED" "Unknown file: $1"
          list_files
          exit 1
        fi
      else
        backup_all
      fi
      ;;
    deploy)
      if [[ -n "${1:-}" ]]; then
        if [[ -v "FILE_MAPPINGS[$1]" ]]; then
          deploy_file "$1"
        else
          print_msg "$RED" "Unknown file: $1"
          list_files
          exit 1
        fi
      else
        deploy_all
      fi
      ;;
    create-backup)
      create_backup
      ;;
    push)
      git_push "${1:-}"
      ;;
    list)
      list_files
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      print_msg "$RED" "Unknown command: $cmd"
      show_help
      exit 1
      ;;
  esac
}

main "$@"
