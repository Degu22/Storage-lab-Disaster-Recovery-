#!/usr/bin/env bash
# ==============================================================================
# Script Name   : reset_lab.sh
# Purpose       : Reverts all failure simulations and returns storage to a healthy baseline.
# ==============================================================================

set -euo pipefail

TARGET_MOUNT="/srv/nfs_share"
DUMMY_FILE="${TARGET_MOUNT}/disposable_capacity_test_dummy.bin"

echo "[+] Starting Lab Reset & Recovery Handler..."

# 1. Clean up capacity simulation dummy files
if [[ -f "${DUMMY_FILE}" ]]; then
    echo "[*] Removing dummy capacity test file..."
    rm -f "${DUMMY_FILE}"
fi

# 2. Remove network partition UFW rule
echo "[*] Clearing simulated network partition firewall rules..."
ufw delete deny proto tcp from any to any port 2049 2>/dev/null || true

# 3. Ensure NFS kernel server is started and enabled
echo "[*] Ensuring nfs-kernel-server service is running..."
systemctl start nfs-kernel-server || true
systemctl enable nfs-kernel-server || true

# 4. Reload NFS exports
echo "[*] Refreshing NFS export table..."
exportfs -arv

echo ""
echo "[SUCCESS] Environment restored to healthy baseline:"
df -h "${TARGET_MOUNT}"
systemctl status nfs-kernel-server --no-pager | head -n 5
