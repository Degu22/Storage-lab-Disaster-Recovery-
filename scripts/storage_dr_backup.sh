#!/usr/bin/env bash
# ==============================================================================
# Script Name   : storage_dr_backup.sh
# Purpose       : Automated LVM snapshot creation, rsync replication, and
#                 cryptographic SHA-256 data-integrity validation for Disaster Recovery.
# Author        : Devi Prasad Gudipally (Storage DevSecOps Engineer)
# SLA           : RPO < 1 Hour, RTO < 15 Minutes
# ==============================================================================

set -euo pipefail

# Configuration Variables
VG_NAME="vg_storage"
LV_NAME="lv_data"
SNAP_NAME="lv_data_snap"
SNAP_SIZE="5G"
SNAP_MOUNT="/mnt/snapshot_temp"
BACKUP_TARGET="devops_admin@192.168.10.30:/backup/dr_repo/latest/"
LOG_FILE="/var/log/storage_dr_backup.log"
MANIFEST_DIR="/var/log/storage_manifests"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

mkdir -p "${MANIFEST_DIR}" "$(dirname "${LOG_FILE}")"

log() {
    local level="$1"
    local msg="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${msg}" | tee -a "${LOG_FILE}"
}

cleanup() {
    log "INFO" "Executing cleanup trap..."
    if mountpoint -q "${SNAP_MOUNT}"; then
        umount "${SNAP_MOUNT}" || true
    fi
    if [ -d "${SNAP_MOUNT}" ]; then
        rmdir "${SNAP_MOUNT}" || true
    fi
    if lvs "/dev/${VG_NAME}/${SNAP_NAME}" &>/dev/null; then
        lvremove -y "/dev/${VG_NAME}/${SNAP_NAME}" || true
    fi
    log "INFO" "Cleanup complete."
}
trap cleanup EXIT ERR

log "INFO" "Starting Disaster Recovery backup job [Timestamp: ${TIMESTAMP}]"

# Step 1: Create Point-in-Time LVM Snapshot (zero disruption to active writers)
log "INFO" "Creating LVM snapshot: ${SNAP_NAME} (Size: ${SNAP_SIZE})"
lvcreate -L "${SNAP_SIZE}" -s -n "${SNAP_NAME}" "/dev/${VG_NAME}/${LV_NAME}"

# Step 2: Mount snapshot read-only
mkdir -p "${SNAP_MOUNT}"
mount -o ro,nouuid "/dev/${VG_NAME}/${SNAP_NAME}" "${SNAP_MOUNT}"
log "INFO" "Mounted read-only snapshot to ${SNAP_MOUNT}"

# Step 3: Cryptographic Data-Integrity Generation (Pre-Transfer SHA-256)
SOURCE_MANIFEST="${MANIFEST_DIR}/manifest_${TIMESTAMP}.sha256"
log "INFO" "Generating pre-transfer SHA-256 hash manifest..."
cd "${SNAP_MOUNT}"
find . -type f -exec sha256sum {} + | sort > "${SOURCE_MANIFEST}"
TOTAL_FILES=$(wc -l < "${SOURCE_MANIFEST}")
log "INFO" "Generated SHA-256 checksums for ${TOTAL_FILES} files."

# Step 4: Replicate to Remote DR Target via Rsync over SSH
log "INFO" "Replicating snapshot to remote DR target: ${BACKUP_TARGET}"
rsync -avzh --delete --stats "${SNAP_MOUNT}/" "${BACKUP_TARGET}" >> "${LOG_FILE}" 2>&1

# Copy the hash manifest to the DR target for audit trail
scp -q "${SOURCE_MANIFEST}" "devops_admin@192.168.10.30:/backup/dr_repo/manifests/"

# Step 5: Post-Transfer Data Integrity Verification
log "INFO" "Triggering remote SHA-256 checksum verification on DR target..."
ssh -q devops_admin@192.168.10.30 \
    "cd /backup/dr_repo/latest && sha256sum -c /backup/dr_repo/manifests/manifest_${TIMESTAMP}.sha256 --quiet"

log "INFO" "SUCCESS: Remote SHA-256 verification passed with 0 corruptions."
log "INFO" "Backup and Data Integrity Verification completed successfully."
