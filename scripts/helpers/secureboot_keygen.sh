#!/bin/bash

# Secure Boot Key Generator for Arch Linux
# Generates a self-signed certificate and private key for signing kernels/UKIs

set -euo pipefail

# === CONFIGURATION ===

KEY_DIR="/boot/efi/loader/keys"
KEY_NAME="satyarch"
DAYS_VALID=3650  # ~10 years

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Create key directory
mkdir -p "$KEY_DIR"

KEY_PATH="${KEY_DIR}/${KEY_NAME}.key"
CERT_PATH="${KEY_DIR}/${KEY_NAME}.crt"
PEM_PATH="${KEY_DIR}/${KEY_NAME}.pem"

# === FUNCTION ===

generate_keys() {
  echo "Generating Secure Boot keys in: $KEY_DIR"

  # Check for existing keys
  if [[ -f "$KEY_PATH" || -f "$CERT_PATH" ]]; then
    echo "Warning: Keys already exist in $KEY_DIR"
    read -p "Overwrite existing keys? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
      echo "Operation canceled."
      exit 1
    fi
  fi

  # Step 1: Generate private key
  openssl genrsa -out "$KEY_PATH" 4096

  # Step 2: Create self-signed X.509 certificate
  openssl req -new -x509 -sha256 -days "$DAYS_VALID" \
    -subj "/CN=Satyanet Secure Boot DB/" \
    -key "$KEY_PATH" \
    -out "$CERT_PATH"

  # Step 3: Combine into .pem for MOK enrollment or sbverify
  cat "$CERT_PATH" "$KEY_PATH" > "$PEM_PATH"

  # Secure the private key
  chmod 600 "$KEY_PATH"
  chmod 600 "$PEM_PATH"
  chmod 644 "$CERT_PATH"

  echo "Keys generated successfully:"
  echo "  Private key: $KEY_PATH"
  echo "  Certificate: $CERT_PATH"
  echo "  Combined PEM: $PEM_PATH"
  echo
  echo "Important: The private key has been secured with chmod 600."
  echo "   Keep your private key safe - it's used to sign the kernels!"
}

# === Usage ===

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 generate"
  exit 1
fi

case "$1" in
  generate) generate_keys ;;
  *) echo "Unknown command: $1"; exit 1 ;;
esac
