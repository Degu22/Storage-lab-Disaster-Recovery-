# Standard Operating Procedure (SOP) & Incident Response Runbook

**Service:** Enterprise NFS Shared Storage Service (`10.0.2.10:/srv/nfs_share`)  
**Scope:** P1/P2 Storage Outage Triage, Filesystem Corruption, Capacity Saturation, and S3 Disaster Recovery  
**Target SLAs:** RPO < 1 Hour | RTO < 15 Minutes

---

## 1. Incident Severity Definitions

| Severity | Definition | Example Scenario | Initial Response SLA |
| :--- | :--- | :--- | :--- |
| **P1 - Critical** | Complete service outage or data unavailability affecting all compute clients. | NFS daemon crash, network partition, or unrecoverable filesystem corruption. | < 15 Minutes |
| **P2 - Major** | Storage capacity or performance degradation approaching critical thresholds. | Storage pool utilization > 90%, I/O latency > 50ms, or backup failure. | < 30 Minutes |
| **P3 - Warning** | Early warning threshold reached; service remains fully operational. | Storage pool utilization > 80%, inode usage > 85%. | < 2 Hours |

---

## 2. Emergency Triage & Diagnostic Workflow

When a storage alert is received from Prometheus or an application reports I/O failure:

```
[Alert Received] ──> [Run storage_health_check.sh on Storage Server]
                            │
            ┌───────────────┴───────────────┐
            ▼                               ▼
    [Capacity Full (>90%)]          [Service Inactive / Crash]
            │                               │
    [Run Emergency Extension]       [Inspect journalctl -u nfs-kernel-server]
            │                               │
            ▼                               ▼
    [Live lvextend + xfs_growfs]    [Restart Daemon or Restore from S3]
```

### Initial Triage Commands (Run on Storage Server):
```bash
# 1. Run automated diagnostic probe
sudo /opt/scripts/monitoring/storage_health_check.sh

# 2. Check kernel logs for I/O errors or SCSI/NVMe drops
sudo dmesg -T | grep -E "xfs|nfs|nvme|error"

# 3. Check service state
sudo systemctl status nfs-kernel-server
```

---

## 3. Step-by-Step Recovery Procedures

### Scenario A: Storage Capacity Exhaustion (>90%)
If the volume has filled up:
1. Extend the underlying LVM logical volume:
   ```bash
   sudo lvextend -L +10G /dev/vg_storage/lv_data
   ```
2. Grow the XFS filesystem live without unmounting:
   ```bash
   sudo xfs_growfs /srv/nfs_share
   ```
3. Verify new capacity:
   ```bash
   df -h /srv/nfs_share
   ```

### Scenario B: Data Corruption or Catastrophic Loss (S3 Disaster Recovery)
If live data is corrupted or deleted:
1. **Isolate the share:** Prevent client write conflicts by unexporting:
   ```bash
   sudo exportfs -u "*:/srv/nfs_share"
   ```
2. **Execute staged restore from S3:**
   ```bash
   export S3_BUCKET="<your-dr-bucket-name>"
   sudo -E /opt/scripts/recovery/restore_from_s3.sh <LATEST_BACKUP_TIMESTAMP>
   ```
3. **Audit staged data and execute cutover:**
   ```bash
   sudo -E /opt/scripts/recovery/restore_from_s3.sh <LATEST_BACKUP_TIMESTAMP> --confirm-cutover
   ```
4. **Validate service and client access:**
   ```bash
   sudo /opt/scripts/recovery/validate_restore.sh
   ```

### 3.1 Disaster Recovery Rollback Procedure
If restored data fails verification or the cutover must be reverted:
1. `restore_from_s3.sh` automatically creates a pre-restore backup in `/srv/nfs_pre_restore_backup_<START_TIME>`.
2. Temporarily pause client access:
   ```bash
   sudo exportfs -u "*:/srv/nfs_share"
   ```
3. Revert to the pre-restore safety copy:
   ```bash
   sudo rsync -avh --delete "/srv/nfs_pre_restore_backup_<TIMESTAMP>/" "/srv/nfs_share/"
   ```
4. Re-export the share and verify service state:
   ```bash
   sudo exportfs -arv
   sudo /opt/scripts/recovery/validate_restore.sh
   ```

---

## 4. Post-Incident Review Template (RCA)

Following resolution of any P1/P2 storage incident, complete this post-mortem:

```text
INCIDENT POST-MORTEM REPORT
Incident Reference : INC-YYYYMMDD-XX
Date & Time        : [ISO Timestamp]
Duration / RTO     : [Measured downtime in minutes/seconds]
Data Loss / RPO    : [Time elapsed since last successful S3 snapshot]
Root Cause         : [Technical explanation of trigger and failure mechanism]
Resolution Summary : [Steps taken to restore healthy baseline]
Corrective Actions :
  1. [Preventative measure - e.g. alert threshold tuning]
  2. [Automation improvement - e.g. logrotate policy or capacity quota]
```
