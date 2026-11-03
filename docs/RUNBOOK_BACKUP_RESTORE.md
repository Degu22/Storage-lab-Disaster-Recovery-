# Operational Runbook: S3 Backup & Disaster Recovery Restoration

## 1. Overview & Recovery Objectives

* **Target RPO (Recovery Point Objective):** < 1 Hour (Achieved via automated hourly LVM snapshot backups).
* **Target RTO (Recovery Time Objective):** < 15 Minutes (Achieved via staged download and automated cutover).
* **Data Integrity SLA:** 100% Cryptographic Verification (SHA-256).

---

## 2. Backup Execution Procedure

### Manual Trigger:
```bash
export S3_BUCKET="your-dr-bucket-name"
sudo -E /opt/scripts/backup/backup_to_s3.sh
```

### Automation via Cron:
To run backups at the top of every hour:
```text
0 * * * * root S3_BUCKET="your-dr-bucket-name" /opt/scripts/backup/backup_to_s3.sh >> /var/log/cron_s3_backup.log 2>&1
```

---

## 3. Independent Integrity Audit Procedure

Verify the cryptographic validity of any S3 backup without restoring it:
```bash
export S3_BUCKET="your-dr-bucket-name"
/opt/scripts/backup/verify_backup.sh <TIMESTAMP>
# Example:
/opt/scripts/backup/verify_backup.sh 20261103_150000
```
Expected output:
```text
[SUCCESS] DATA INTEGRITY CONFIRMED: Backup archive is 100% bit-consistent with source manifest.
```

---

## 4. Disaster Recovery Restoration Procedure (Staged with Safety Gate)

### Step 1: Execute Staged Restoration (Safe download & hash audit)
```bash
export S3_BUCKET="your-dr-bucket-name"
sudo -E /opt/scripts/recovery/restore_from_s3.sh 20261103_150000
```
*Note: This unpacks data into `/srv/nfs_restore_staging/` and validates hashes without altering the live share.*

### Step 2: Audit Staged Data
Inspect files and verify completeness:
```bash
ls -la /srv/nfs_restore_staging/extracted_data/
```

### Step 3: Production Cutover Gate
When ready to switch live traffic to the restored data:
```bash
sudo -E /opt/scripts/recovery/restore_from_s3.sh 20261103_150000 --confirm-cutover
```

### Step 4: Validate Restored Service
```bash
sudo /opt/scripts/recovery/validate_restore.sh
```
