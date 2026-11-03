#!/usr/bin/env bash
# ==============================================================================
# Script Name   : simulate_nfs_failure.sh
# Purpose       : Controlled simulation of NFS server daemon crash.
# Precondition  : Must be executed on the NFS Storage Server.
# ==============================================================================

set -euo pipefail

echo "[+] Initiating controlled NFS service interruption simulation..."

# Step 1: Stop NFS kernel server service
echo "[*] Stopping nfs-kernel-server service..."
systemctl stop nfs-kernel-server

echo "[!] NFS service stopped."
echo "[*] Verification: Check 'systemctl status nfs-kernel-server'"
echo "[*] Verification on Client: Client accesses to /mnt/nfs_share will now hang or report timeout."
echo "[*] Verification in Prometheus: Check 'NFSDown' or 'StorageServiceUnavailable' alert rule."
echo ""
echo "To recover service, run:"
echo "  sudo systemctl start nfs-kernel-server"
echo "  or run: ./reset_lab.sh"
