#!/usr/bin/env bash
# ==============================================================================
# Script Name   : verify_backup.sh
# Purpose       : Audits and cryptographically verifies an S3 disaster recovery
#                 backup against its SHA-256 manifest and tarball structure.
# ==============================================================================

set -euo pipefail

S3_BUCKET="${S3_BUCKET:-}"
BACKUP_TIMESTAMP="${1:-}"
TEMP_VERIFY_DIR="/tmp/dr_backup_verification_$$"

if [[ -z "${S3_BUCKET}" ]]; then
    echo "ERROR: S3_BUCKET environment variable must be set." >&2
    exit 2
fi

if [[ -z "${BACKUP_TIMESTAMP}" ]]; then
    echo "Usage: $0 <BACKUP_TIMESTAMP>"
    echo "Example: $0 20261103_140000"
    echo "Available backups in s3://${S3_BUCKET}/backups/:"
    aws s3 ls "s3://${S3_BUCKET}/backups/" || true
    exit 1
fi

# Validate timestamp format (YYYYMMDD_HHMMSS)
if [[ ! "${BACKUP_TIMESTAMP}" =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
    echo "ERROR: Invalid timestamp format '${BACKUP_TIMESTAMP}'. Expected YYYYMMDD_HHMMSS." >&2
    exit 3
fi

ARCHIVE="nfs_backup_${BACKUP_TIMESTAMP}.tar.gz"
MANIFEST="nfs_backup_${BACKUP_TIMESTAMP}.sha256"

# Verify object existence in S3 before downloading
if ! aws s3api head-object --bucket "${S3_BUCKET}" --key "backups/${BACKUP_TIMESTAMP}/${ARCHIVE}" >/dev/null 2>&1; then
    echo "ERROR: S3 archive not found: s3://${S3_BUCKET}/backups/${BACKUP_TIMESTAMP}/${ARCHIVE}" >&2
    exit 4
fi

mkdir -p "${TEMP_VERIFY_DIR}"
cleanup() {
    rm -rf "${TEMP_VERIFY_DIR}"
}
trap cleanup EXIT ERR

echo "[+] Auditing backup from s3://${S3_BUCKET}/backups/${BACKUP_TIMESTAMP}/"

# Download manifest and archive
aws s3 cp "s3://${S3_BUCKET}/backups/${BACKUP_TIMESTAMP}/${MANIFEST}" "${TEMP_VERIFY_DIR}/${MANIFEST}"
aws s3 cp "s3://${S3_BUCKET}/backups/${BACKUP_TIMESTAMP}/${ARCHIVE}" "${TEMP_VERIFY_DIR}/${ARCHIVE}"

# Calculate local checksum of downloaded archive
EXPECTED_SHA=$(cat "${TEMP_VERIFY_DIR}/${MANIFEST}" | tr -d '[:space:]')
ACTUAL_SHA=$(sha256sum "${TEMP_VERIFY_DIR}/${ARCHIVE}" | awk '{print $1}')

echo "[*] Expected SHA-256 : ${EXPECTED_SHA}"
echo "[*] Actual SHA-256   : ${ACTUAL_SHA}"

if [[ "${EXPECTED_SHA}" != "${ACTUAL_SHA}" ]]; then
    echo "[CRITICAL FAILURE] CORRUPTION DETECTED: Downloaded archive failed cryptographic audit!" >&2
    exit 5
fi

# Verify archive internal structure
echo "[*] Verifying internal tarball structure..."
if ! tar -tzf "${TEMP_VERIFY_DIR}/${ARCHIVE}" >/dev/null 2>&1; then
    echo "[CRITICAL FAILURE] Archive is corrupt or cannot be unpacked!" >&2
    exit 6
fi

TOTAL_FILES=$(tar -tzf "${TEMP_VERIFY_DIR}/${ARCHIVE}" | wc -l)
echo "[SUCCESS] DATA INTEGRITY CONFIRMED: ${TOTAL_FILES} files verified bit-consistent with source manifest."
exit 0
