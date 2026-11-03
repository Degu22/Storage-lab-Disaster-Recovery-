# Enterprise Storage Service Lifecycle & Disaster Recovery Lab

A production-grade reference implementation and automation suite demonstrating enterprise Linux shared storage administration (NFSv4), configuration automation with Ansible, automated disaster recovery (DR) using LVM snapshots and `rsync`, cryptographic data integrity verification (`sha256`), and observability with Prometheus & Grafana.

---

## 1. Architecture Overview

```
                      +-------------------------------------------------------+
                      |           MANAGEMENT & MONITORING PLANE              |
                      |   Prometheus (Port 9090) + Grafana (Port 3000)       |
                      |   Ansible Control Node (Playbooks & Jinja2 Templates)|
                      +-------------------------------------------------------+
                                                 │
                                                 ▼ (Metrics Scrape / SSH Config)
+──────────────────────────────────────────────────────────────────────────────────────────────────+
|                                    INTERNAL STORAGE NETWORK                                      |
|                                    Subnet: 192.168.10.0/24                                       |
+──────────────────────────────────────────────────────────────────────────────────────────────────+
       │                                         │                                   │
       ▼                                         ▼                                   ▼
+───────────────────────────+       +───────────────────────────+       +───────────────────────────+
|   NFS Storage Server      |       |     Client Node 01        |       |   DR Backup Target        |
|   IP: 192.168.10.10       |       |     IP: 192.168.10.21     |       |   IP: 192.168.10.30       |
|                           |       |                           |       |                           |
|  - LVM Volume Group:      |       |  - Mount:                 |       |  - Backup Repository:     |
|    vg_storage / lv_data   | NFSv4 |    192.168.10.10:         |       |    /backup/dr_repo/       |
|  - Filesystem: XFS        |◄══════|    /srv/nfs_share         |       |  - Offsite/Secondary Pool |
|  - Export: /srv/nfs_share |:2049  |    -> /mnt/shared_data    |       |                           |
|  - Security: root_squash  |       |  - Config: /etc/fstab     |       |                           |
|  - Node Exporter (:9100)  |       |                           |       |                           |
+───────────────────────────+       +───────────────────────────+       +───────────────────────────+
       │                                                                             ▲
       │                                                                             │
       └───────────────────────────── LVM Snapshot & Rsync ─────────────────────────┘
                                 (Automated DR Script + SHA-256 Check)
```

---

## 2. Recovery Objectives (SLA)

| Metric | Target | Implemented Mechanism |
| :--- | :--- | :--- |
| **RPO (Recovery Point Objective)** | < 1 Hour | Automated hourly point-in-time LVM snapshot replication. |
| **RTO (Recovery Time Objective)** | < 15 Minutes | Automated failover mount redirect and one-click restore scripts. |
| **Data Integrity Verification** | 100% Bit-level | Cryptographic SHA-256 pre- and post-transfer checksum verification. |

---

## 3. Repository Structure

```text
enterprise-storage-dr-lab/
├── README.md                               # High-level architecture and quickstart
├── ansible/
│   ├── inventory.ini                       # Host definitions and connection variables
│   └── playbooks/
│       ├── 01_setup_nfs_server.yml          # LVM setup, XFS formatting, exports, firewalld
│       ├── 02_configure_clients.yml        # Client mounting, /etc/fstab persistence, permissions
│       └── 03_validate_storage.yml         # Security checks (root_squash, POSIX ACLs)
├── scripts/
│   ├── storage_dr_backup.sh               # LVM snapshot, rsync sync, sha256 checksums
│   ├── disaster_recovery_restore.sh       # Rapid rollback & restore procedure
│   └── simulate_failure.sh                # Storage exhaustion and failover simulation test
├── monitoring/
│   ├── prometheus.yml                      # Scrape configs for storage exporters
│   └── storage_alerts.rules.yml            # Prometheus alert rules (capacity, I/O latency)
└── docs/
    ├── ARCHITECTURE.md                     # Deep technical storage & network design
    └── RUNBOOK_INCIDENT_DISASTER_RECOVERY.md # Incident post-mortem & standard operating procedure (SOP)
```

---

## 4. Key Highlights for Technical Interviews

1. **Storage Tiering & LVM Management:**
   * Utilizes Linux Logical Volume Manager (LVM) on underlying block devices (`/dev/sdb`) to allow dynamic online volume expansion (`lvextend`) and instantaneous zero-overhead point-in-time snapshots (`lvcreate --snapshot`).
2. **DevSecOps & NFS Hardening:**
   * Restricts exports strictly to the authorized `/24` subnet.
   * Enforces `root_squash` in `/etc/exports` to prevent remote root escalation attacks.
   * Applies `firewalld` rules restricting port `2049` (NFSv4) exclusively to storage clients.
3. **Automated Verification:**
   * Every backup run calculates a manifest of SHA-256 hashes for all active datasets before transmission and compares them against the secondary target to guarantee zero bit-rot or transfer corruption.
4. **Day-2 Observability:**
   * Prometheus alerts configured for storage thresholds (>80% Warning, >90% Critical) and disk I/O saturation (`await` time > 50ms).
