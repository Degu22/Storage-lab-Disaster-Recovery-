#!/usr/bin/env bash
# ==============================================================================
# Script Name   : reset_lab.sh
# Purpose       : Reverts all failure simulations and returns storage to a healthy baseline.
# ==============================================================================

set -euo pipefail

TARGET_MOUNT="/srv/nfs_share"

echo "[+] Starting Lab Reset & Recovery Handler..."

# 1. Clean up capacity simulation dummy files
echo "[*] Cleaning up any disposable capacity test dummy files..."
find "${TARGET_MOUNT}" -maxdepth 1 -name ".disposable_capacity_test_dummy*" -exec rm -f {} + 2>/dev/null || true

# 2. Remove specifically the simulated network partition UFW rule
echo "[*] Removing simulated network partition UFW rule (LAB_TEST_NFS_PARTITION)..."
ufw delete deny proto tcp from any to any port 2049 2>/dev/null || true
while read -r rule_num; do
    if [[ -n "${rule_num}" ]]; then
        echo "y" | ufw delete "${rule_num}" 2>/dev/null || true
    fi
done < <(ufw status numbered 2>/dev/null | grep "LAB_TEST_NFS_PARTITION" | sed -e 's/\[//' -e 's/\].*//' | tr -d ' ' || true)

# 3. Ensure NFS kernel server is started and enabled
echo "[*] Ensuring nfs-kernel-server service is active..."
systemctl start nfs-kernel-server || true
systemctl enable nfs-kernel-server || true

# 4. Reload NFS exports
echo "[*] Refreshing NFS export table..."
exportfs -arv

echo ""
echo "[SUCCESS] Environment restored to healthy baseline:"
df -h "${TARGET_MOUNT}"
systemctl status nfs-kernel-server --no-pager | head -n 5
exit 0
