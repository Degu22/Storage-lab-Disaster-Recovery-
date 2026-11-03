#!/usr/bin/env bash
# ==============================================================================
# Script Name   : simulate_capacity_warning.sh
# Purpose       : Creates a disposable dummy file on the dedicated NFS volume
#                 to trigger Prometheus StorageCapacity alert thresholds safely.
# Safety Rules  : NEVER fills root filesystem. Strictly verified target.
# ==============================================================================

set -euo pipefail

TARGET_MOUNT="/srv/nfs_share"
DUMMY_FILE="${TARGET_MOUNT}/disposable_capacity_test_dummy.bin"

# Safety Check 1: Ensure target mount is mounted and NOT the root filesystem
if [[ "$(findmnt -n -o TARGET "${TARGET_MOUNT}")" != "${TARGET_MOUNT}" ]]; then
    echo "ERROR: ${TARGET_MOUNT} is not a separate mountpoint! Refusing to run to protect OS root disk." >&2
    exit 1
fi

TOTAL_MB=$(df -m "${TARGET_MOUNT}" | awk 'NR==2 {print $2}')
AVAIL_MB=$(df -m "${TARGET_MOUNT}" | awk 'NR==2 {print $4}')

# Calculate 85% fill target (leaving 15% headroom)
TARGET_FILL_MB=$(( TOTAL_MB * 85 / 100 ))
CURRENT_USED_MB=$(( TOTAL_MB - AVAIL_MB ))
ALLOCATE_MB=$(( TARGET_FILL_MB - CURRENT_USED_MB ))

if (( ALLOCATE_MB <= 0 )); then
    echo "[!] Filesystem is already at or above 85% capacity (${CURRENT_USED_MB}MB used / ${TOTAL_MB}MB total)."
    exit 0
fi

echo "[+] Safely creating ${ALLOCATE_MB}MB dummy file at ${DUMMY_FILE} to trigger warning alert..."
fallocate -l "${ALLOCATE_MB}M" "${DUMMY_FILE}" || dd if=/dev/zero of="${DUMMY_FILE}" bs=1M count="${ALLOCATE_MB}" status=progress

echo "[SUCCESS] Storage pool capacity adjusted to >80% threshold:"
df -h "${TARGET_MOUNT}"
echo ""
echo "[*] Check Prometheus Alertmanager for 'StorageVolumeNearCapacity' alert."
echo "To clean up, run: ./reset_lab.sh"
