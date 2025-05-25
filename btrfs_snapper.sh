#!/bin/bash

# Btrfs Snapshot Manager for Arch Linux
# Automates creating, listing, and cleaning snapshots with retention policies

set -euo pipefail

# === Configuration ===
SNAPSHOT_DIR="/.snapshots"
ROOT_SUBVOL="@"
MAX_SNAPSHOTS=10  # Maximum number to keep

# === Functions ===
create_snapshot() {
  local name="${1:-auto}"
  local timestamp=$(date +%Y%m%d-%H%M)
  local snap_name="${name}-${timestamp}"
  
  echo "Creating snapshot: $snap_name"
  btrfs subvolume snapshot -r / "${SNAPSHOT_DIR}/${snap_name}"
  
  echo "Snapshot created at: ${SNAPSHOT_DIR}/${snap_name}"
  prune_old_snapshots
}

list_snapshots() {
  echo "===== Btrfs Snapshots ====="
  if [[ ! -d "$SNAPSHOT_DIR" ]]; then
    echo "Error: Snapshot directory not found"
    return 1
  fi
  
  ls -lh "$SNAPSHOT_DIR" | grep -v "total" | sort -r
  echo "=========================="
}

prune_old_snapshots() {
  echo "Checking for old snapshots to prune..."
  local count=$(ls -1 "$SNAPSHOT_DIR" | wc -l)
  
  if [[ $count -le $MAX_SNAPSHOTS ]]; then
    echo "No pruning needed. ($count/$MAX_SNAPSHOTS snapshots)"
    return 0
  fi
  
  # Get oldest snapshots beyond our limit
  local to_remove=$((count - MAX_SNAPSHOTS))
  echo "Removing oldest $to_remove snapshots..."
  
  ls -1t "$SNAPSHOT_DIR" | tail -n "$to_remove" | while read snap; do
    echo "Deleting: ${SNAPSHOT_DIR}/${snap}"
    btrfs subvolume delete "${SNAPSHOT_DIR}/${snap}"
  done
  
  echo "Pruning complete. Now at $MAX_SNAPSHOTS snapshots."
}

# === Main ===
case "${1:-help}" in
  create)
    create_snapshot "${2:-auto}" ;;
  list)
    list_snapshots ;;
  prune)
    prune_old_snapshots ;;
  help|*)
    echo "Usage: $0 {create|list|prune}"
    echo "  create [name] - Create a new snapshot (optional custom name)"
    echo "  list          - List existing snapshots"
    echo "  prune         - Remove oldest snapshots beyond max count"
    ;;
esac