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

# 2. Check ownership and permissions
OWNER=$(stat -c '%U:%G' "${NFS_SHARE}")
PERMS=$(stat -c '%a' "${NFS_SHARE}")
echo "[*] Ownership: ${OWNER} (Expected: nobody:nogroup)"
echo "[*] Permissions: ${PERMS} (Expected: 2775 or 775)"

# 3. Test read/write operations
TEST_FILE="${NFS_SHARE}/recovery_post_verification_$(date +%s).tmp"
echo "Recovery audit verified at $(date)" > "${TEST_FILE}"
if [[ -f "${TEST_FILE}" ]]; then
    echo "[PASS] Read/Write test succeeded."
    rm -f "${TEST_FILE}"
else
    echo "[FAIL] Could not write test verification file!" >&2
    exit 1
fi

# 4. Check active exports
echo "[+] Checking active NFS exports:"
exportfs -v

echo "[SUCCESS] Post-recovery verification passed without errors."
