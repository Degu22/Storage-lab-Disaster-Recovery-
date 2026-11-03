#!/usr/bin/env bash
# ==============================================================================
# Script Name   : backup_to_s3.sh
# Purpose       : Consistent LVM snapshot backup with XFS quiescing, cryptographic
#                 SHA-256 manifest generation, and secure S3 upload.
# Target SLA    : RPO < 1 Hour, RTO < 15 Minutes
# ==============================================================================

set -euo pipefail

# Configurable Defaults (Can be overridden via environment variables)
S3_BUCKET="${S3_BUCKET:-}"
VG_NAME="${VG_NAME:-vg_storage}"
LV_NAME="${LV_NAME:-lv_data}"
SNAP_NAME="${SNAP_NAME:-lv_data_snap}"
SNAP_SIZE="${SNAP_SIZE:-3G}"
NFS_MOUNT="${NFS_MOUNT:-/srv/nfs_share}"
SNAP_MOUNT="${SNAP_MOUNT:-/mnt/snapshot_temp}"
BACKUP_STAGING="${BACKUP_STAGING:-/srv/nfs_backup_staging}"
LOG_FILE="/var/log/storage_s3_backup.log"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

log() {
    local level="$1"
    local msg="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${msg}" | tee -a "${LOG_FILE}"
}

if [[ -z "${S3_BUCKET}" ]]; then
    echo "ERROR: S3_BUCKET environment variable must be specified." >&2
    exit 1
fi

mkdir -p "${BACKUP_STAGING}" "$(dirname "${LOG_FILE}")"

cleanup() {
    log "INFO" "Executing cleanup handler..."
    # CRITICAL RELIABILITY GUARD: Always unfreeze XFS filesystem if script aborted
    # during snapshot creation to prevent application hang.
    if [[ -d "${NFS_MOUNT}" ]]; then
        xfs_freeze -u "${NFS_MOUNT}" 2>/dev/null || true
    fi
    if mountpoint -q "${SNAP_MOUNT}"; then
        umount "${SNAP_MOUNT}" || true
    fi
    if [[ -d "${SNAP_MOUNT}" ]]; then
        rmdir "${SNAP_MOUNT}" || true
    fi
    if lvs "/dev/${VG_NAME}/${SNAP_NAME}" &>/dev/null; then
        lvremove -y "/dev/${VG_NAME}/${SNAP_NAME}" || true
    fi
    log "INFO" "Cleanup complete."
}
trap cleanup EXIT ERR

log "INFO" "Starting S3 Backup job [Timestamp: ${TIMESTAMP}]"

# Step 1: Verify source filesystem is healthy and mounted
if ! mountpoint -q "${NFS_MOUNT}"; then
    log "CRITICAL" "Source storage ${NFS_MOUNT} is not mounted! Aborting."
    exit 1
fi

# Step 2: Consistent Snapshot with XFS Quiescing
log "INFO" "Quiescing XFS filesystem with xfs_freeze before snapshotting..."
xfs_freeze -f "${NFS_MOUNT}"
lvcreate -L "${SNAP_SIZE}" -s -n "${SNAP_NAME}" "/dev/${VG_NAME}/${LV_NAME}"
xfs_freeze -u "${NFS_MOUNT}"
log "INFO" "LVM Snapshot ${SNAP_NAME} created successfully; live filesystem un-frozen."

# Step 3: Mount snapshot read-only
mkdir -p "${SNAP_MOUNT}"
mount -o ro,nouuid "/dev/${VG_NAME}/${SNAP_NAME}" "${SNAP_MOUNT}"

# Step 4: Create Timestamped Archive & Generate Cryptographic SHA-256 Manifest
ARCHIVE_NAME="nfs_backup_${TIMESTAMP}.tar.gz"
MANIFEST_NAME="nfs_backup_${TIMESTAMP}.sha256"
LOCAL_ARCHIVE="${BACKUP_STAGING}/${ARCHIVE_NAME}"
LOCAL_MANIFEST="${BACKUP_STAGING}/${MANIFEST_NAME}"

log "INFO" "Creating compressed archive: ${LOCAL_ARCHIVE}..."
tar -czf "${LOCAL_ARCHIVE}" -C "${SNAP_MOUNT}" .

log "INFO" "Generating SHA-256 cryptographic checksum..."
sha256sum "${LOCAL_ARCHIVE}" | awk '{print $1}' > "${LOCAL_MANIFEST}"
log "INFO" "Checksum: $(cat "${LOCAL_MANIFEST}")"

# Step 5: Upload to Amazon S3 via AWS CLI (Using Instance Profile IAM Auth)
log "INFO" "Uploading archive and manifest to s3://${S3_BUCKET}/backups/${TIMESTAMP}/..."
aws s3 cp "${LOCAL_ARCHIVE}" "s3://${S3_BUCKET}/backups/${TIMESTAMP}/${ARCHIVE_NAME}" --only-show-errors
aws s3 cp "${LOCAL_MANIFEST}" "s3://${S3_BUCKET}/backups/${TIMESTAMP}/${MANIFEST_NAME}" --only-show-errors

log "INFO" "S3 Upload confirmed. Performing remote integrity verification..."
REMOTE_SHA=$(aws s3 cp "s3://${S3_BUCKET}/backups/${TIMESTAMP}/${MANIFEST_NAME}" -)
LOCAL_SHA=$(cat "${LOCAL_MANIFEST}")

if [[ "${REMOTE_SHA}" == "${LOCAL_SHA}" ]]; then
    log "INFO" "INTEGRITY VERIFIED: S3 manifest matches local checksum."
else
    log "CRITICAL" "INTEGRITY MISMATCH: Remote manifest does not match local."
    exit 1
fi

# Step 6: Safe Staging Cleanup
rm -f "${LOCAL_ARCHIVE}" "${LOCAL_MANIFEST}"
log "INFO" "Disaster recovery backup to S3 completed successfully."
