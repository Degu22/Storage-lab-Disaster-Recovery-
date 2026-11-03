#!/usr/bin/env bash
# ==============================================================================
# Script Name   : disaster_recovery_restore.sh
# Purpose       : Emergency restore procedure from remote DR target to live NFS share
#                 with automated post-restore SHA-256 validation.
# Author        : Devi Prasad Gudipally (Storage DevSecOps Engineer)
# Target RTO    : < 15 Minutes
# ==============================================================================

set -euo pipefail

RESTORE_SRC="devops_admin@192.168.10.30:/backup/dr_repo/latest/"
MANIFEST_SRC="devops_admin@192.168.10.30:/backup/dr_repo/manifests/"
NFS_SHARE="/srv/nfs_share"
LOG_FILE="/var/log/storage_dr_restore.log"
START_TIME=$(date +%s)

log() {
    local level="$1"
    local msg="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${msg}" | tee -a "${LOG_FILE}"
}

log "WARN" "INITIATING EMERGENCY RESTORE PROCEDURE ON LIVE NFS SHARE: ${NFS_SHARE}"

# Step 1: Temporarily unexport NFS share to prevent write conflicts during restoration
log "INFO" "Unexporting NFS shares during sync..."
exportfs -u "*:${NFS_SHARE}" || true

# Step 2: Fetch the latest verified SHA-256 manifest
LATEST_MANIFEST="/tmp/latest_restore_manifest.sha256"
log "INFO" "Retrieving latest cryptographic manifest from DR target..."
ssh -q devops_admin@192.168.10.30 "ls -t /backup/dr_repo/manifests/*.sha256 | head -1" | \
    xargs -I {} scp -q devops_admin@192.168.10.30:{} "${LATEST_MANIFEST}"

# Step 3: Rsync data back from DR Target to local storage
log "INFO" "Syncing data from DR repository to primary storage pool..."
rsync -avzh --delete "${RESTORE_SRC}" "${NFS_SHARE}/" >> "${LOG_FILE}" 2>&1

# Step 4: Validate Data Integrity Post-Restoration
log "INFO" "Executing bit-level SHA-256 checksum verification on restored filesystem..."
cd "${NFS_SHARE}"
if sha256sum -c "${LATEST_MANIFEST}" --quiet; then
    log "INFO" "DATA INTEGRITY VERIFIED: All restored files match cryptographic signatures."
else
    log "CRITICAL" "INTEGRITY CHECK FAILED: Restored files differ from source manifest!"
    exit 1
fi

# Step 5: Restore permissions and re-export NFS share
log "INFO" "Restoring SELinux contexts and re-exporting NFS..."
restorecon -R "${NFS_SHARE}" || true
exportfs -arv

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

log "INFO" "DISASTER RECOVERY RESTORATION COMPLETE."
log "INFO" "Actual RTO Achieved: ${ELAPSED} seconds (Target: < 900 seconds / 15 mins)."
