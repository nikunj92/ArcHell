#!/bin/bash

# Secure Boot KeyTool Helper for Arch Linux (Alienware m18)
# - Installs KeyTool.efi
# - Converts your .crt into .auth for key enrollment
# - Helps you copy it to ESP or USB
# - Explains usage in firmware

set -euo pipefail

KEY_DIR="/root/secureboot"
EFI_TOOLS_DIR="/boot/efi/EFI/tools"
USB_MOUNT="/mnt/usb"

KEYTOOL_SRC="/usr/lib/efitools/x86_64/KeyTool.efi"
SIGLIST="${KEY_DIR}/db.esl"
AUTHFILE="${KEY_DIR}/db.auth"
CERT="${KEY_DIR}/db.crt"
KEY="${KEY_DIR}/db.key"
EFI_GUID="deadbeef-dead-beef-dead-beefdeadbeef"  # Replace if desired

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

install_keytool() {
  echo "Installing efitools..."
  if ! pacman -Qi efitools &>/dev/null; then
    pacman -S --noconfirm efitools
    echo "efitools installed."
  else
    echo "efitools already installed."
  fi
}

copy_keytool_to_esp() {
  echo "Copying KeyTool.efi to EFI/tools..."
  
  if [[ ! -f "$KEYTOOL_SRC" ]]; then
    echo "KeyTool.efi not found at: $KEYTOOL_SRC"
    echo "   Did you run the install step first?"
    exit 1
  fi
  
  mkdir -p "$EFI_TOOLS_DIR"
  cp "$KEYTOOL_SRC" "$EFI_TOOLS_DIR/"
  echo "KeyTool.efi copied to: $EFI_TOOLS_DIR"
}

make_auth_file() {
  echo "Converting $CERT to .auth format for UEFI enrollment..."

  if [[ ! -f "$CERT" ]]; then
    echo "Certificate not found: $CERT"
    echo "   Did you generate secure boot keys first?"
    exit 1
  fi

  if [[ ! -f "$KEY" ]]; then
    echo "Private key not found: $KEY"
    exit 1
  fi

  # Create key directory if it doesn't exist
  mkdir -p "$KEY_DIR"

  # 1. Generate EFI Signature List (ESL)
  cert-to-efi-sig-list "$CERT" "$SIGLIST"

  # 2. Sign ESL into AUTH file
  sign-efi-sig-list -k "$KEY" -c "$CERT" db "$SIGLIST" "$AUTHFILE" "$EFI_GUID"

  echo "Created:"
  echo "  ESL:  $SIGLIST"
  echo "  AUTH: $AUTHFILE"
}

copy_to_usb() {
  echo "Copying KeyTool.efi and .auth to USB"

  if ! mountpoint -q "$USB_MOUNT"; then
    echo "USB not mounted at $USB_MOUNT. Please mount it first."
    echo "   Example: mount /dev/sdX1 $USB_MOUNT"
    exit 1
  fi

  if [[ ! -f "$KEYTOOL_SRC" ]]; then
    echo "KeyTool.efi not found. Run the install step first."
    exit 1
  fi

  if [[ ! -f "$AUTHFILE" ]]; then
    echo "AUTH file not found. Run the make-auth step first."
    exit 1
  fi

  mkdir -p "$USB_MOUNT/EFI/tools"
  cp "$KEYTOOL_SRC" "$USB_MOUNT/EFI/tools/"
  cp "$AUTHFILE" "$USB_MOUNT/"
  echo "Copied to USB for booting: $USB_MOUNT"
}

usage_instructions() {
  echo
  echo "HOW TO USE KeyTool.efi (for enrolling your Secure Boot key):"
  echo "1. Reboot and press F2 (Alienware) to access UEFI setup menu."
  echo "2. Choose USB or internal ESP entry: EFI/tools/KeyTool.efi"
  echo "3. Inside KeyTool:"
  echo "   - Choose 'Edit Keys'"
  echo "   - Navigate to 'db' → 'Replace' or 'Append'"
  echo "   - Load your signed AUTH file (db.auth)"
  echo "4. Save and reboot. Your Secure Boot DB will now trust your key."
  echo
  echo "TIP: If KeyTool refuses to load, verify UEFI is in Setup Mode or enroll via MokManager"
}

# === Script Dispatch ===

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 {install|copy-to-esp|make-auth|copy-to-usb|guide|all}"
  exit 1
fi

case "$1" in
  install) install_keytool ;;
  copy-to-esp) copy_keytool_to_esp ;;
  make-auth) make_auth_file ;;
  copy-to-usb) copy_to_usb ;;
  guide) usage_instructions ;;
  all)
    install_keytool
    make_auth_file
    copy_keytool_to_esp
    usage_instructions
    ;;
  *) echo "Unknown command: $1"; exit 1 ;;
esac
