#!/usr/bin/env bash
# ==============================================================================
# Script Name   : restore_from_s3.sh
# Purpose       : Controlled, staged Disaster Recovery restoration from S3 with
#                 pre-cutover integrity checks and safety cutover gates.
# Target SLA    : RTO < 15 Minutes
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
    exit 1
fi

mkdir -p "${RESTORE_STAGING}" "$(dirname "${LOG_FILE}")"

log "INFO" "Initiating Disaster Recovery restore pipeline for backup: ${BACKUP_TIMESTAMP}"

# Step 1: Download from Amazon S3 into isolated Staging Directory
ARCHIVE="nfs_backup_${BACKUP_TIMESTAMP}.tar.gz"
MANIFEST="nfs_backup_${BACKUP_TIMESTAMP}.sha256"

log "INFO" "Downloading backup artifacts from S3 into ${RESTORE_STAGING}..."
aws s3 cp "s3://${S3_BUCKET}/backups/${BACKUP_TIMESTAMP}/${MANIFEST}" "${RESTORE_STAGING}/${MANIFEST}"
aws s3 cp "s3://${S3_BUCKET}/backups/${BACKUP_TIMESTAMP}/${ARCHIVE}" "${RESTORE_STAGING}/${ARCHIVE}"

# Step 2: Validate Data Integrity BEFORE unpacking
log "INFO" "Verifying cryptographic SHA-256 integrity..."
EXPECTED_SHA=$(cat "${RESTORE_STAGING}/${MANIFEST}" | tr -d '[:space:]')
ACTUAL_SHA=$(sha256sum "${RESTORE_STAGING}/${ARCHIVE}" | awk '{print $1}')

if [[ "${EXPECTED_SHA}" != "${ACTUAL_SHA}" ]]; then
    log "CRITICAL" "INTEGRITY CHECK FAILED: Downloaded archive is corrupt! Aborting restore."
    exit 1
fi
log "INFO" "Cryptographic integrity passed. Unpacking archive into staging tree..."

# Step 3: Extract archive into staging folder
STAGING_DATA="${RESTORE_STAGING}/extracted_data"
rm -rf "${STAGING_DATA}"
mkdir -p "${STAGING_DATA}"
tar -xzf "${RESTORE_STAGING}/${ARCHIVE}" -C "${STAGING_DATA}"
log "INFO" "Archive extracted cleanly into staging location: ${STAGING_DATA}"

# Step 4: Controlled Cutover Gate
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

# Step 5: Production Cutover Execution
log "WARN" "CONFIRMATION RECEIVED: Executing live storage cutover to ${LIVE_NFS_SHARE}..."

# Pause NFS writes by unexporting temporarily
exportfs -u "*:${LIVE_NFS_SHARE}" || true

# Synchronize staged data into live directory without deleting non-staged files without backup
rsync -avh --backup --backup-dir="/srv/nfs_pre_restore_backup_${START_TIME}" "${STAGING_DATA}/" "${LIVE_NFS_SHARE}/"

# Re-apply ownership & permissions (nobody:nogroup on Ubuntu)
chown -R nobody:nogroup "${LIVE_NFS_SHARE}"
chmod 2775 "${LIVE_NFS_SHARE}"

# Re-export share
exportfs -arv
log "INFO" "Live NFS share re-exported and active."

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
log "INFO" "DISASTER RECOVERY CUTOVER COMPLETE."
log "INFO" "Actual Measured RTO: ${ELAPSED} seconds."
