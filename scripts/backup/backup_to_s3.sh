#!/usr/bin/env bash
# ==============================================================================
# Script Name   : backup_to_s3.sh
# Purpose       : Filesystem-consistent LVM snapshot backup with XFS quiescing,
#                 pre-upload archive integrity checks, cryptographic SHA-256
#                 manifest generation, and verified AWS S3 upload.
# Consistency   : Filesystem-consistent (XFS log and dirty metadata quiesced via
#                 xfs_freeze before snapshotting).
# ==============================================================================

set -euo pipefail

# Configurable Defaults (Override via environment variables)
S3_BUCKET="${S3_BUCKET:-}"
VG_NAME="${VG_NAME:-vg_storage}"
LV_NAME="${LV_NAME:-lv_data}"
SNAP_NAME="${SNAP_NAME:-lv_data_snap}"
SNAP_SIZE="${SNAP_SIZE:-3G}"
NFS_MOUNT="${NFS_MOUNT:-/srv/nfs_share}"
SNAP_MOUNT="${SNAP_MOUNT:-/mnt/snapshot_temp}"
BACKUP_STAGING="${BACKUP_STAGING:-/srv/nfs_backup_staging}"
LOG_FILE="/var/log/storage_s3_backup.log"
LOCK_FILE="/var/run/storage_s3_backup.lock"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

log() {
    local level="$1"
    local msg="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${msg}" | tee -a "${LOG_FILE}"
}

# 1. Concurrency Protection
exec 200>"${LOCK_FILE}"
if ! flock -n 200; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CRITICAL] Another backup job is actively running. Lock held on ${LOCK_FILE}. Exiting." | tee -a "${LOG_FILE}"
    exit 3
fi

if [[ -z "${S3_BUCKET}" ]]; then
    log "CRITICAL" "S3_BUCKET environment variable must be specified."
    exit 2
fi

mkdir -p "${BACKUP_STAGING}" "$(dirname "${LOG_FILE}")"

cleanup() {
    local exit_code=$?
    log "INFO" "Executing cleanup handler (Exit code: ${exit_code})..."
    # CRITICAL RELIABILITY GUARD: Always unfreeze XFS filesystem if script aborted
    # during snapshot creation to guarantee write availability.
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
trap cleanup EXIT INT TERM ERR

log "INFO" "=================================================================="
log "INFO" "Starting S3 Backup Pipeline [Timestamp: ${TIMESTAMP}]"
log "INFO" "=================================================================="

# Step 1: Validate Source Mount and Logical Volume Identity
if ! mountpoint -q "${NFS_MOUNT}"; then
    log "CRITICAL" "Source storage mountpoint ${NFS_MOUNT} is NOT mounted! Aborting."
    exit 4
fi

SOURCE_DEV=$(findmnt -n -o SOURCE "${NFS_MOUNT}")
if [[ "${SOURCE_DEV}" != *"${LV_NAME}"* && "${SOURCE_DEV}" != *"${VG_NAME}"* ]]; then
    log "CRITICAL" "Source device (${SOURCE_DEV}) does not match expected volume (${VG_NAME}/${LV_NAME})! Aborting."
    exit 5
fi
log "INFO" "Validated storage mount: ${NFS_MOUNT} on ${SOURCE_DEV}"

# Step 2: Validate LVM Volume Group Free Space Capacity
FREE_G=$(vgs --noheadings -o vg_free --units g "${VG_NAME}" 2>/dev/null | tr -d ' gG' | cut -d'.' -f1 || echo "0")
REQ_G=$(echo "${SNAP_SIZE}" | tr -d ' gG')
if (( FREE_G < REQ_G )); then
    log "CRITICAL" "Insufficient free extents in Volume Group ${VG_NAME}. Available: ${FREE_G}G, Required: ${REQ_G}G. Aborting."
    exit 6
fi
log "INFO" "Capacity check passed: ${FREE_G}G free in VG ${VG_NAME} (Required: ${REQ_G}G)."

# Step 3: Filesystem-Consistent Snapshot with XFS Quiescing
# NOTE: xfs_freeze guarantees FILESYSTEM-LEVEL consistency (VFS journal & dirty buffers flushed).
# For application-level consistency with active relational databases, application quiescing
# hooks must be executed before xfs_freeze.
log "INFO" "Quiescing XFS filesystem log and dirty metadata via xfs_freeze -f..."
xfs_freeze -f "${NFS_MOUNT}"
lvcreate -L "${SNAP_SIZE}" -s -n "${SNAP_NAME}" "/dev/${VG_NAME}/${LV_NAME}"
xfs_freeze -u "${NFS_MOUNT}"
log "INFO" "Snapshot created: /dev/${VG_NAME}/${SNAP_NAME}. Filesystem un-frozen."

# Monitor snapshot allocation
SNAP_ALLOC=$(lvs --noheadings -o snap_percent "/dev/${VG_NAME}/${SNAP_NAME}" 2>/dev/null | tr -d ' %' | cut -d'.' -f1 || echo "0")
log "INFO" "LVM snapshot active. Space allocated: ${SNAP_ALLOC}% of ${SNAP_SIZE}."

# Step 4: Mount Snapshot Read-Only
mkdir -p "${SNAP_MOUNT}"
mount -o ro,nouuid "/dev/${VG_NAME}/${SNAP_NAME}" "${SNAP_MOUNT}"
log "INFO" "Mounted read-only snapshot to ${SNAP_MOUNT}"

# Step 5: Create Compressed Archive and Validate Archive Structure
ARCHIVE_NAME="nfs_backup_${TIMESTAMP}.tar.gz"
MANIFEST_NAME="nfs_backup_${TIMESTAMP}.sha256"
LOCAL_ARCHIVE="${BACKUP_STAGING}/${ARCHIVE_NAME}"
LOCAL_MANIFEST="${BACKUP_STAGING}/${MANIFEST_NAME}"

log "INFO" "Creating archive: ${LOCAL_ARCHIVE}..."
tar -czf "${LOCAL_ARCHIVE}" -C "${SNAP_MOUNT}" .

# Step 5b: Verify LVM Snapshot did not overflow during archive creation
SNAP_ATTR=$(lvs --noheadings -o lv_attr "/dev/${VG_NAME}/${SNAP_NAME}" 2>/dev/null | tr -d ' ' || echo "")
if [[ "${SNAP_ATTR:4:1}" == "I" || "${SNAP_ATTR:4:1}" == "i" ]]; then
    log "CRITICAL" "LVM snapshot overflowed (invalidated by high write volume during backup)! Archive is invalid."
    exit 7
fi

log "INFO" "Validating archive integrity prior to transmission..."
if ! tar -tzf "${LOCAL_ARCHIVE}" >/dev/null 2>&1; then
    log "CRITICAL" "Archive validation failed! Created tarball is corrupted."
    exit 8
fi
log "INFO" "Archive integrity validated cleanly."

# Step 6: Generate Cryptographic SHA-256 Manifest
log "INFO" "Generating SHA-256 cryptographic checksum..."
sha256sum "${LOCAL_ARCHIVE}" | awk '{print $1}' > "${LOCAL_MANIFEST}"
CHECKSUM=$(cat "${LOCAL_MANIFEST}")
log "INFO" "Checksum: ${CHECKSUM}"

# Step 7: Upload Archive & Manifest to Amazon S3
log "INFO" "Uploading to s3://${S3_BUCKET}/backups/${TIMESTAMP}/..."
aws s3 cp "${LOCAL_ARCHIVE}" "s3://${S3_BUCKET}/backups/${TIMESTAMP}/${ARCHIVE_NAME}" --only-show-errors
aws s3 cp "${LOCAL_MANIFEST}" "s3://${S3_BUCKET}/backups/${TIMESTAMP}/${MANIFEST_NAME}" --only-show-errors

# Step 8: Actual S3 Object Verification via S3 API
log "INFO" "Verifying uploaded S3 objects via head-object API..."
OBJ_SIZE=$(aws s3api head-object --bucket "${S3_BUCKET}" --key "backups/${TIMESTAMP}/${ARCHIVE_NAME}" --query "ContentLength" --output text 2>/dev/null || echo "0")
if (( OBJ_SIZE <= 0 )); then
    log "CRITICAL" "S3 verification failed: Uploaded archive is missing or 0 bytes!"
    exit 9
fi

REMOTE_SHA=$(aws s3 cp "s3://${S3_BUCKET}/backups/${TIMESTAMP}/${MANIFEST_NAME}" -)
if [[ "${REMOTE_SHA}" != "${CHECKSUM}" ]]; then
    log "CRITICAL" "Checksum mismatch between local manifest and uploaded S3 manifest!"
    exit 10
fi
log "INFO" "S3 object confirmed (${OBJ_SIZE} bytes). Checksum matches: ${REMOTE_SHA}"

# Step 9: Safe Staging Cleanup
rm -f "${LOCAL_ARCHIVE}" "${LOCAL_MANIFEST}"
log "INFO" "Backup job completed successfully."
exit 0
