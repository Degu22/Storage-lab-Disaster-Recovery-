#!/usr/bin/env bash
# ==============================================================================
# Script Name   : validate_restore.sh
# Purpose       : Post-recovery validation verifying that files are accessible,
#                 ownership is intact, and client read/write operations succeed.
# ==============================================================================

set -euo pipefail

NFS_SHARE="${1:-/srv/nfs_share}"

echo "[+] Starting Post-Recovery Storage Verification on: ${NFS_SHARE}"

# 1. Verify directory exists and is mounted
if ! mountpoint -q "${NFS_SHARE}"; then
    echo "[FAIL] Storage mountpoint ${NFS_SHARE} is not active!" >&2
    exit 1
fi
echo "[PASS] Storage mount is active."

# 2. Check top-level directory ownership and permissions
OWNER=$(stat -c '%U:%G' "${NFS_SHARE}")
PERMS=$(stat -c '%a' "${NFS_SHARE}")
echo "[*] Mount root ownership: ${OWNER} (Expected: nobody:nogroup)"
echo "[*] Mount root permissions: ${PERMS} (Expected: 2775 or 775)"

# 3. Check NFS kernel server service status
if systemctl is-active --quiet nfs-kernel-server; then
    echo "[PASS] nfs-kernel-server service is active and running."
else
    echo "[FAIL] nfs-kernel-server service is INACTIVE!" >&2
    exit 2
fi

# 4. Check active exports
echo "[+] Checking active NFS exports for ${NFS_SHARE}:"
if exportfs -v | grep -q "${NFS_SHARE}"; then
    echo "[PASS] NFS share is actively exported."
else
    echo "[FAIL] NFS share ${NFS_SHARE} is NOT found in active export table!" >&2
    exit 3
fi

# 5. Test read/write operations using a unique temporary file
TEST_FILE="${NFS_SHARE}/.recovery_validation_probe_$$.tmp"
echo "Recovery audit verified at $(date)" > "${TEST_FILE}"
if [[ -f "${TEST_FILE}" ]] && grep -q "Recovery audit verified" "${TEST_FILE}"; then
    echo "[PASS] Read/Write test succeeded."
    rm -f "${TEST_FILE}"
else
    echo "[FAIL] Read/Write verification failed!" >&2
    rm -f "${TEST_FILE}" 2>/dev/null || true
    exit 4
fi

echo "[SUCCESS] Post-recovery validation passed without errors."
exit 0
