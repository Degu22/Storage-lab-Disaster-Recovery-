#!/usr/bin/env bash
# ==============================================================================
# Script Name   : restore_from_s3.sh
# Purpose       : Controlled, staged Disaster Recovery restoration from S3 with
#                 pre-extraction validation, permission preservation, and
#                 explicit cutover gate.
# ==============================================================================

set -euo pipefail

S3_BUCKET="${S3_BUCKET:-}"
BACKUP_TIMESTAMP="${1:-}"
CONFIRM_FLAG="${2:-}"
RESTORE_STAGING="${RESTORE_STAGING:-/srv/nfs_restore_staging}"
LIVE_NFS_SHARE="${LIVE_NFS_SHARE:-/srv/nfs_share}"
LOG_FILE="/var/log/storage_dr_restore.log"
START_TIME=$(date +%s)

log() {
    local level="$1"
    local msg="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${msg}" | tee -a "${LOG_FILE}"
}

if [[ -z "${S3_BUCKET}" || -z "${BACKUP_TIMESTAMP}" ]]; then
    echo "Usage: $0 <BACKUP_TIMESTAMP> [--confirm-cutover]"
    echo "Example: $0 20261103_140000"
    exit 2
fi

cleanup() {
    local exit_code=$?
    if (( exit_code != 0 )); then
        log "WARN" "Restore process interrupted or encountered an error (Exit code: ${exit_code})."
        # Ensure NFS export is restored if unexported prior to failure
        exportfs -arv 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM ERR

# 1. Parameter & Timestamp Validation
if [[ ! "${BACKUP_TIMESTAMP}" =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
    log "CRITICAL" "Invalid timestamp format '${BACKUP_TIMESTAMP}'. Expected YYYYMMDD_HHMMSS."
    exit 3
fi

# 2. Safety Gate: Reject Unsafe Staging Paths
case "${RESTORE_STAGING}" in
    "/"|"/bin"|"/boot"|"/dev"|"/etc"|"/home"|"/lib"*|"/proc"|"/root"|"/run"|"/sys"|"/tmp"|"/usr"*|"/var"*)
        log "CRITICAL" "Unsafe staging path rejected: '${RESTORE_STAGING}'. Staging must be an isolated directory."
        exit 4
        ;;
esac

mkdir -p "${RESTORE_STAGING}" "$(dirname "${LOG_FILE}")"

log "INFO" "Initiating Disaster Recovery restore pipeline for backup: ${BACKUP_TIMESTAMP}"

# Step 1: Download from Amazon S3 into isolated Staging Directory
ARCHIVE="nfs_backup_${BACKUP_TIMESTAMP}.tar.gz"
MANIFEST="nfs_backup_${BACKUP_TIMESTAMP}.sha256"

if ! aws s3api head-object --bucket "${S3_BUCKET}" --key "backups/${BACKUP_TIMESTAMP}/${ARCHIVE}" >/dev/null 2>&1; then
    log "CRITICAL" "Backup archive s3://${S3_BUCKET}/backups/${BACKUP_TIMESTAMP}/${ARCHIVE} does not exist!"
    exit 5
fi

log "INFO" "Downloading backup artifacts from S3 into ${RESTORE_STAGING}..."
aws s3 cp "s3://${S3_BUCKET}/backups/${BACKUP_TIMESTAMP}/${MANIFEST}" "${RESTORE_STAGING}/${MANIFEST}"
aws s3 cp "s3://${S3_BUCKET}/backups/${BACKUP_TIMESTAMP}/${ARCHIVE}" "${RESTORE_STAGING}/${ARCHIVE}"

# Step 2: Validate Data Integrity BEFORE unpacking
log "INFO" "Verifying cryptographic SHA-256 integrity..."
EXPECTED_SHA=$(cat "${RESTORE_STAGING}/${MANIFEST}" | tr -d '[:space:]')
ACTUAL_SHA=$(sha256sum "${RESTORE_STAGING}/${ARCHIVE}" | awk '{print $1}')

if [[ "${EXPECTED_SHA}" != "${ACTUAL_SHA}" ]]; then
    log "CRITICAL" "INTEGRITY CHECK FAILED: Downloaded archive is corrupt! Aborting restore."
    exit 6
fi
log "INFO" "Cryptographic integrity passed."

# Step 3: Validate Archive Contents Against Path Traversal and Symlink Escapes
log "INFO" "Inspecting archive contents for unsafe paths..."
if tar -tzf "${RESTORE_STAGING}/${ARCHIVE}" | grep -E "(^\/|\.\.)"; then
    log "CRITICAL" "SECURITY VIOLATION: Archive contains absolute paths or parent traversal (..)!"
    exit 7
fi

log "INFO" "Inspecting archive for unsafe symlink targets..."
if tar -tvf "${RESTORE_STAGING}/${ARCHIVE}" | grep -E '^l' | grep -E ' -> (/[^ ]*|\.\.)'; then
    log "CRITICAL" "SECURITY VIOLATION: Archive contains symlinks pointing to absolute paths or escaping parent directories!"
    exit 8
fi

# Step 4: Extract Archive (Preserving original file permissions and owners)
STAGING_DATA="${RESTORE_STAGING}/extracted_data"
rm -rf "${STAGING_DATA}"
mkdir -p "${STAGING_DATA}"
log "INFO" "Extracting archive with preserved original permissions (--same-owner -p)..."
tar -xzpf "${RESTORE_STAGING}/${ARCHIVE}" --same-owner -C "${STAGING_DATA}"

# Step 5: Controlled Cutover Gate
if [[ "${CONFIRM_FLAG}" != "--confirm-cutover" ]]; then
    echo ""
    echo "================================================================================"
    echo "[STAGING COMPLETE] Data successfully staged and cryptographically validated."
    echo "Staged Path: ${STAGING_DATA}"
    echo "Live Path  : ${LIVE_NFS_SHARE}"
    echo ""
    echo "SAFETY GATE: To execute production cutover, run this script with '--confirm-cutover':"
    echo "  $0 ${BACKUP_TIMESTAMP} --confirm-cutover"
    echo "================================================================================"
    exit 0
fi

# Step 6: Production Cutover Execution
log "WARN" "CONFIRMATION RECEIVED: Executing live storage cutover to ${LIVE_NFS_SHARE}..."

# Pause NFS writes by unexporting temporarily
exportfs -u "*:${LIVE_NFS_SHARE}" || true

# Preserve existing live data to rollback directory before cutover
ROLLBACK_DIR="/srv/nfs_pre_restore_backup_${START_TIME}"
log "INFO" "Creating live data safety snapshot in ${ROLLBACK_DIR}..."
mkdir -p "${ROLLBACK_DIR}"
rsync -avh --backup --backup-dir="${ROLLBACK_DIR}" "${STAGING_DATA}/" "${LIVE_NFS_SHARE}/"

# Re-apply top-level export directory permission (non-recursive to preserve restored file permissions)
chown nobody:nogroup "${LIVE_NFS_SHARE}"
chmod 2775 "${LIVE_NFS_SHARE}"

# Re-export share and verify service state
exportfs -arv
systemctl is-active --quiet nfs-kernel-server || systemctl restart nfs-kernel-server

if ! exportfs -v | grep -q "${LIVE_NFS_SHARE}"; then
    log "CRITICAL" "Failed to verify active export for ${LIVE_NFS_SHARE}!"
    exit 9
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
log "INFO" "=================================================================="
log "INFO" "DISASTER RECOVERY CUTOVER COMPLETE."
log "INFO" "Actual Measured Recovery Duration: ${ELAPSED} seconds."
log "INFO" "Rollback data preserved at: ${ROLLBACK_DIR}"
log "INFO" "=================================================================="
exit 0
