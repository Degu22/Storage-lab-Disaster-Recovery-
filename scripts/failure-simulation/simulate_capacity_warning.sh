#!/usr/bin/env bash
# ==============================================================================
# Script Name   : simulate_capacity_warning.sh
# Purpose       : Creates a disposable dummy file on the dedicated NFS volume
#                 to safely trigger Prometheus StorageCapacity alerts.
# Safety Rules  :
#   - Explicit confirmation required (--confirm)
#   - Strictly verified dedicated mountpoint (NEVER fills root /)
#   - Hard ceiling on dummy allocation (Maximum 5GB)
# ==============================================================================

set -euo pipefail

TARGET_MOUNT="/srv/nfs_share"
DUMMY_FILE="${TARGET_MOUNT}/.disposable_capacity_test_dummy.bin"
MAX_CAP_MB=5120 # 5 GiB maximum allocation safety ceiling

cleanup() {
    local exit_code=$?
    if (( exit_code != 0 )) && [[ -f "${DUMMY_FILE}" ]]; then
        echo "[!] Simulation interrupted or failed (Exit code: ${exit_code}). Cleaning up partial dummy file..."
        rm -f "${DUMMY_FILE}"
    fi
}
trap cleanup EXIT INT TERM ERR

if [[ "${1:-}" != "--confirm" ]]; then
    echo "================================================================================"
    echo "SAFETY GATE: Storage Capacity Warning Simulation"
    echo "This script safely generates a temporary dummy file on ${TARGET_MOUNT} to adjust"
    echo "disk usage above 80% to test Prometheus Alertmanager notifications."
    echo ""
    echo "To proceed, run: $0 --confirm"
    echo "================================================================================"
    exit 1
fi

# Safety Check 1: Ensure target mount is mounted and NOT the root filesystem
ROOT_MOUNT=$(findmnt -n -o TARGET /)
TARGET_REAL=$(findmnt -n -o TARGET "${TARGET_MOUNT}" 2>/dev/null || echo "")

if [[ -z "${TARGET_REAL}" || "${TARGET_REAL}" == "${ROOT_MOUNT}" ]]; then
    echo "ERROR: ${TARGET_MOUNT} is not a mounted dedicated filesystem! Aborting to protect root OS." >&2
    exit 2
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

# Apply hard safety ceiling
if (( ALLOCATE_MB > MAX_CAP_MB )); then
    echo "[!] Calculated allocation (${ALLOCATE_MB}MB) exceeds safety cap (${MAX_CAP_MB}MB). Capping at ${MAX_CAP_MB}MB."
    ALLOCATE_MB=${MAX_CAP_MB}
fi

echo "[+] Safely creating ${ALLOCATE_MB}MB disposable file at ${DUMMY_FILE}..."
fallocate -l "${ALLOCATE_MB}M" "${DUMMY_FILE}" || dd if=/dev/zero of="${DUMMY_FILE}" bs=1M count="${ALLOCATE_MB}" status=progress

echo ""
echo "[SUCCESS] Storage pool capacity adjusted to test alert threshold:"
df -h "${TARGET_MOUNT}"
echo ""
echo "[*] Verify: Prometheus Alert 'StorageVolumeNearCapacity' should fire in ~5 minutes."
echo "[*] Cleanup: Run ./reset_lab.sh to remove the test file."
exit 0
