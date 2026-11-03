#!/usr/bin/env bash
# ==============================================================================
# Script Name   : storage_health_check.sh
# Purpose       : Fast host-level diagnostic probe checking LVM, XFS, NFS, and UFW.
# ==============================================================================

set -euo pipefail

NFS_MOUNT="/srv/nfs_share"
VG_NAME="vg_storage"
LV_NAME="lv_data"

echo "================================================================================"
echo "          ENTERPRISE STORAGE SERVICE HEALTH & DIAGNOSTIC PROBE                  "
echo "================================================================================"
echo "Host: $(hostname -f) | Kernel: $(uname -r) | Date: $(date)"
echo ""

echo "--- 1. LVM Physical & Volume Group Health ---"
vgs "${VG_NAME}" 2>/dev/null || echo "[WARN] Volume group ${VG_NAME} not found."
lvs "/dev/${VG_NAME}/${LV_NAME}" 2>/dev/null || echo "[WARN] Logical volume ${LV_NAME} not found."
echo ""

echo "--- 2. Filesystem Capacity & Inodes (${NFS_MOUNT}) ---"
if mountpoint -q "${NFS_MOUNT}"; then
    df -h "${NFS_MOUNT}"
    echo ""
    df -i "${NFS_MOUNT}"
else
    echo "[CRITICAL] Mountpoint ${NFS_MOUNT} is NOT MOUNTED!"
fi
echo ""

echo "--- 3. NFS Server Service Status ---"
systemctl is-active nfs-kernel-server && echo "[OK] nfs-kernel-server is active." || echo "[FAIL] nfs-kernel-server is INACTIVE."
echo ""

echo "--- 4. Active NFS Exports ---"
exportfs -v || echo "[WARN] No exports active."
echo ""

echo "--- 5. Network & Listening Ports (TCP 2049, 9100) ---"
ss -tulpn | grep -E "2049|9100" || echo "[WARN] Required ports not listening."
echo ""

echo "--- 6. Node Exporter Status ---"
systemctl is-active prometheus-node-exporter && echo "[OK] prometheus-node-exporter is active." || echo "[WARN] Node exporter is inactive."
echo "================================================================================"
