#!/bin/bash

# Arch Linux Secure Boot Signing Helper
# Signs a .efi file (like a UKI or systemd-boot binary) with your custom keys

set -euo pipefail

# === CONFIGURATION ===
KEY_DIR="/root/secureboot"
CERT="${KEY_DIR}/db.crt"
KEY="${KEY_DIR}/db.key"

# Default input/output — override via CLI
DEFAULT_INPUT="/boot/efi/EFI/Linux/arch-linux.efi"
DEFAULT_OUTPUT="/boot/efi/EFI/Linux/arch-linux-signed.efi"

# === SIGN FUNCTION ===

sign_efi() {
  local input="${1:-$DEFAULT_INPUT}"
  local output="${2:-$DEFAULT_OUTPUT}"

  echo "  Signing EFI binary"
  echo "  Input:  $input"
  echo "  Output: $output"
  echo "  Key:    $KEY"
  echo "  Cert:   $CERT"

  # Check for required files
  if [[ ! -f "$input" ]]; then
    echo " Error: Input EFI binary not found: $input"
    exit 1
  fi
  
  if [[ ! -f "$KEY" ]]; then
    echo " Error: Signing key not found: $KEY"
    exit 1
  fi
  
  if [[ ! -f "$CERT" ]]; then
    echo " Error: Certificate not found: $CERT"
    exit 1
  fi
  
  # Check if sbsign is installed
  if ! command -v sbsign &> /dev/null; then
    echo " Error: sbsign not found. Install sbsigntools package."
    exit 1
  fi

  # Sign the file
  sbsign --key "$KEY" --cert "$CERT" --output "$output" "$input"

  echo "Signature applied successfully."
  
  # Verify if possible
  if command -v sbverify &> /dev/null; then
    echo "Verifying signature..."
    sbverify --list "$output" || echo " Warning: Could not verify signature"
  else
    echo " Warning: sbverify not found, unable to verify signature."
  fi
}

# === QUICK VERIFY FUNCTION ===

verify_signature() {
  local target="${1:-$DEFAULT_OUTPUT}"
  echo "Verifying: $target"
  
  if [[ ! -f "$target" ]]; then
    echo " Error: Target file not found: $target"
    exit 1
  fi
  
  if ! command -v sbverify &> /dev/null; then
    echo " Error: sbverify not found. Install sbsigntools package."
    exit 1
  fi
  
  sbverify --list "$target"
}

# === Usage ===

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <command> [args]"
  echo "Commands:"
  echo "  sign [input] [output]     Sign a file (defaults to UKI path)"
  echo "  verify [target]           Verify signature"
  exit 1
fi

# === Dispatch ===
cmd="$1"; shift
case "$cmd" in
  sign) sign_efi "$@" ;;
  verify) verify_signature "$@" ;;
  *) echo " Unknown command: $cmd"; exit 1 ;;
esac
