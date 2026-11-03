# Standard Operating Procedure (SOP) & Incident Report: Storage Failure & Disaster Recovery

**Incident ID:** INC-STORAGE-2026-0814  
**Severity:** P1 (Critical Outage Simulation)  
**System Affected:** Primary NFS Storage Service (`192.168.10.10:/srv/nfs_share`)  
**Responder:** Devi Prasad Gudipally (Storage DevSecOps Engineer)  
**Status:** RESOLVED — Full Recovery Verified

---

## 1. Incident Scenario & Trigger
* **09:15 UTC:** Prometheus Alertmanager fired alert `StorageVolumeCriticallyFull` (>92% utilization) followed by simulated filesystem corruption on `/srv/nfs_share`.
* **09:17 UTC:** Client nodes reported I/O read/write errors on `/mnt/shared_data`.

---

## 2. Root Cause Analysis (RCA)
* An uncontrolled, runaway logging job filled the active Logical Volume to capacity. Concurrently, data corruption occurred in the active application data directory, leaving files in an inconsistent state.

---

## 3. Step-by-Step Restoration Procedure Executed

### Step 1: Isolation & Triage
1. Acknowledged the incident in Jira/PagerDuty and communicated maintenance status to application stakeholders.
2. Unexported the corrupted share to prevent client nodes from writing partial data:
   ```bash
   sudo exportfs -u "*:/srv/nfs_share"
   ```

### Step 2: Emergency Storage Extension
1. Extended the underlying LVM storage pool to eliminate the disk-full lock:
   ```bash
   sudo lvextend -r -L +20G /dev/vg_storage/lv_data
   ```
2. Verified filesystem expanded cleanly via `df -h /srv/nfs_share`.

### Step 3: Disaster Recovery Data Sync from DR Target
1. Executed the disaster recovery restoration script (`/opt/scripts/disaster_recovery_restore.sh`).
2. Synced the last known-good hourly snapshot from the DR target (`192.168.10.30:/backup/dr_repo/latest/`) back into `/srv/nfs_share/`.
3. Validated cryptographic integrity using the source SHA-256 hash manifest:
   ```bash
   cd /srv/nfs_share && sha256sum -c /tmp/latest_restore_manifest.sha256 --quiet
   # Result: OK - 0 corruptions detected.
   ```

### Step 4: Service Resumption & Client Mount Validation
1. Re-exported the NFS shares and restored SELinux labels:
   ```bash
   sudo restorecon -R /srv/nfs_share
   sudo exportfs -arv
   ```
2. Ran Ansible client validation playbook (`ansible-playbook -i inventory.ini playbooks/03_validate_storage.yml`) across client nodes.
3. Verified all clients regained full read/write access with active `root_squash` protections.

---

## 4. Recovery Metrics Achieved

| Metric | Target SLA | Actual Achieved | Status |
| :--- | :--- | :--- | :--- |
| **RTO (Recovery Time Objective)** | < 15 Minutes (900s) | **7 minutes 42 seconds** | **EXCEEDED (PASSED)** |
| **RPO (Recovery Point Objective)** | < 1 Hour | **22 minutes of delta** | **PASSED** |
| **Data Integrity Verification** | 100% Match | **100% SHA-256 Validated** | **PASSED** |

---

## 5. Corrective & Preventative Actions
1. **Prometheus Alert Tuning:** Lowered the early-warning threshold to 75% utilization to trigger automated log cleanup before disk reaches 90%.
2. **Logrotate Enforcement:** Deployed automated `logrotate` policies across all compute clients.
3. **Runbook Documentation:** Standardized this SOP into the team knowledge base for 2nd-line operational support.
