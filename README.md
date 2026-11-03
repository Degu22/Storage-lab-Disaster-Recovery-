# Enterprise Storage Service Lifecycle & Disaster Recovery Lab

[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![AWS](https://img.shields.io/badge/AWS-Cloud_Infrastructure-232F3E?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/Terraform-1.5+-844FBA?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Ansible](https://img.shields.io/badge/Ansible-2.15+-EE0000?logo=ansible&logoColor=white)](https://www.ansible.com/)
[![NFSv4](https://img.shields.io/badge/Storage-NFSv4%20%7C%20LVM2%20%7C%20XFS-blue)](https://nfs.sourceforge.net/)
[![Prometheus](https://img.shields.io/badge/Monitoring-Prometheus%20%26%20Grafana-E6522C?logo=prometheus&logoColor=white)](https://prometheus.io/)

A complete, production-grade reference implementation demonstrating the entire lifecycle of an enterprise Linux shared storage service on AWS: automated provisioning via Terraform, configuration management via Ansible, secure multi-client NFSv4 file sharing, automated disaster recovery using LVM snapshots and Amazon S3, cryptographic SHA-256 data-integrity audits, and centralized Prometheus & Grafana observability.

---

## 1. Project Overview & Business Problem

### The Business Challenge
In enterprise R&D, engineering, and data-intensive environments, teams require centralized, highly available, and secure file storage to collaborate, run automated build pipelines, and process datasets. However, traditional unmanaged storage environments suffer from:
1. **Manual Configuration Drift:** Storage servers and client mounts configured by hand lead to inconsistencies, mount timeouts, and privilege escalation vulnerabilities.
2. **Data Loss & Slow Recovery:** Relying on ad-hoc backups without point-in-time consistency or cryptographic validation creates prolonged downtime and risks restoring corrupted data.
3. **Lack of Operational Observability:** Storage teams often discover disk saturation or I/O bottlenecks only after services crash.

### The Solution
This project automates the deployment of a centralized, secure Linux shared storage service built on Ubuntu Server 24.04 LTS, incorporating Infrastructure as Code, automated configuration, crash-consistent backups to Amazon S3, and real-time observability.

---

## 2. Key Engineering Capabilities

* **Storage Lifecycle Management:** Logical Volume Manager (LVM2) over dedicated AWS EBS block devices formatted with the high-performance XFS filesystem, supporting non-disruptive dynamic expansion.
* **DevSecOps & NFS Hardening:** Enforces `root_squash` (mapping client root to `nobody:nogroup`), network subnet export restrictions, and dual-layer firewalls (AWS Security Groups + Ubuntu UFW).
* **Data Protection & DR:** Quiesced LVM snapshots (`xfs_freeze`) uploaded to an encrypted, versioned Amazon S3 bucket with bit-level SHA-256 integrity audits.
* **Controlled Staged Restore:** Restores to an isolated staging area first, requiring explicit verification and authorization before live production cutover.
* **Full-Stack Observability:** Prometheus scrapes host metrics, storage capacity, inode exhaustion, and disk I/O latency, rendered in Grafana with Alertmanager warning thresholds.

---

## 3. Architecture Specification

```
                                      AWS CLOUD (VPC: 10.0.0.0/16)
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                  │
│   MANAGEMENT & MONITORING SUBNET: 10.0.1.0/24                                                    │
│   ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│   │ Node A: Management & Monitoring Server (Ubuntu 24.04 - t3.small)                         │   │
│   │  • Ansible Control Engine          • Prometheus Server (:9090)                           │   │
│   │  • Grafana Server (:3000)          • Alertmanager (:9093)                                │   │
│   └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                │                                                 │
│                                                ▼ (Internal SSH Automation & Metrics Scrape)      │
│   STORAGE & COMPUTE CLIENT SUBNET: 10.0.2.0/24                                                   │
│   ┌──────────────────────────────────────────────┐  ┌─────────────────────────────────────────┐  │
│   │ Node B: NFS Storage Server                   │  │ Node C: NFS Client Compute Node         │  │
│   │ (Ubuntu 24.04 - t3.micro)                    │  │ (Ubuntu 24.04 - t3.micro)               │  │
│   │  • Dedicated 20GB gp3 EBS Volume (Encrypted) │  │  • Mount Point: /mnt/nfs_share          │  │
│   │  • LVM: vg_storage / lv_data                 │  │  • Persistent fstab with _netdev/nofail │  │
│   │  • XFS Filesystem (/srv/nfs_share)           │  │  • Node Exporter (:9100)                │  │
│   │  • NFSv4 Kernel Server (TCP :2049)           │  └─────────────────────────────────────────┘  │
│   │  • Node Exporter (:9100)                     │                       ▲                       │
│   │  • IAM Role: S3 Backup & Restore Engine      │                       │                       │
│   └──────────────────────────────────────────────┘                       │                       │
│                          │ NFSv4 Compound RPC (TCP :2049)                │                       │
│                          └───────────────────────────────────────────────┘                       │
│                                                │                                                 │
│                                                │ AWS CLI / IAM Instance Profile (HTTPS :443)     │
│                                                ▼                                                 │
│   INDEPENDENT DISASTER RECOVERY DESTINATION                                                      │
│   ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│   │ Amazon S3 Bucket: storage-dr-backup-<random-id>                                          │   │
│   │  • AES256 Server-Side Encryption         • Bucket Versioning Active                      │   │
│   │  • Block Public Access (All 4 Enforced)   • 30-Day Lifecycle Retention Rule               │   │
│   └──────────────────────────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Technology Stack & Component Justification

| Layer | Component | Version | Justification |
| :--- | :--- | :--- | :--- |
| **Cloud Infrastructure** | AWS (EC2, EBS, VPC, S3, IAM) | - | Industry-standard enterprise cloud provider with native IAM instance profiles and object storage. |
| **Operating System** | Ubuntu Server | 24.04 LTS (Noble) | Long-term support release with modern Linux kernel (6.8+) supporting advanced XFS and NFSv4.2 features. |
| **Storage Management** | LVM2 & XFS | lvm2 2.03+ / xfsprogs | Logical Volume Manager provides online volume growth; XFS excels at high-throughput scalability and direct I/O. |
| **File Sharing Protocol**| NFSv4.2 | nfs-kernel-server | Modern single-port (TCP 2049) protocol with integrated stateful locking, avoiding legacy portmapper complexity. |
| **Infrastructure as Code**| Terraform | >= 1.5.0 | Modular, declarative, version-controlled cloud infrastructure provisioning. |
| **Configuration Mgmt** | Ansible | >= 2.15 | Agentless, idempotent configuration management using reusable roles and YAML variables. |
| **Observability** | Prometheus, Grafana, Alertmanager | 2.51+ / 10.4+ | De facto cloud-native monitoring stack for metric scraping, time-series analysis, and dashboard visualization. |

---

## 5. Repository Structure

```text
storage-lab-disaster-recovery/
├── .gitignore                                  # Comprehensive Git ignore rules
├── LICENSE                                     # MIT License
├── README.md                                   # Master project documentation
│
├── infrastructure/
│   └── terraform/
│       ├── modules/
│       │   ├── networking/                     # VPC, Subnets, Route Tables, IGW
│       │   ├── security/                       # Security Groups (Mgmt, Storage, Client)
│       │   ├── iam/                            # EC2 Instance Profile, SSM, Scoped S3 Policy
│       │   ├── storage/                        # Dedicated EBS gp3 Volume & S3 DR Bucket
│       │   └── compute/                        # 3x EC2 Ubuntu 24.04 Instances
│       └── environments/
│           └── lab/                            # main.tf, variables.tf, outputs.tf, terraform.tfvars.example
│
├── ansible/
│   ├── ansible.cfg                             # Ansible configuration (roles_path, SSH tuning)
│   ├── inventory/
│   │   ├── hosts.example.ini                   # Parameterized host inventory template
│   │   └── group_vars/
│   │       └── all.yml.example                 # Global project variables
│   ├── playbooks/
│   │   ├── site.yml                            # Master end-to-end orchestration
│   │   ├── nfs-server.yml                      # Storage server provisioning
│   │   ├── nfs-client.yml                      # Client mounting & fstab
│   │   ├── monitoring.yml                      # Prometheus, Grafana, Alertmanager
│   │   └── validation.yml                      # Security assertion & mount verification
│   └── roles/
│       ├── common/                             # Base packages, UFW baseline, Chrony NTP
│       ├── storage/                            # Safe EBS discovery, LVM vg/lv, XFS format
│       ├── nfs_server/                         # NFSv4 kernel server, exports, root_squash
│       ├── nfs_client/                         # nfs-common, /etc/fstab, mount options
│       └── node_exporter/                      # Prometheus host metrics exporter
│
├── scripts/
│   ├── backup/
│   │   ├── backup_to_s3.sh                     # Consistent LVM snapshot, SHA-256, S3 sync
│   │   └── verify_backup.sh                    # Cryptographic manifest verification
│   ├── recovery/
│   │   ├── restore_from_s3.sh                  # Staged restore with cutover gate
│   │   └── validate_restore.sh                 # Post-recovery integrity & write check
│   ├── monitoring/
│   │   └── storage_health_check.sh             # Host-level diagnostic CLI probe
│   └── failure-simulation/
│       ├── simulate_nfs_failure.sh             # Controlled daemon crash
│       ├── simulate_capacity_warning.sh        # Controlled disk fill test (>80%)
│       ├── simulate_network_failure.sh         # Network partition simulation
│       └── reset_lab.sh                        # Return environment to clean baseline
│
├── monitoring/
│   ├── prometheus/
│   │   ├── prometheus.yml                      # Scrape config for all 3 nodes
│   │   └── rules/
│   │       └── storage_alerts.yml              # Production PromQL alert rules
│   ├── grafana/
│   │   ├── dashboards/
│   │   │   └── storage_overview.json           # Complete exported Grafana dashboard
│   │   └── provisioning/
│   │       ├── datasources/datasource.yml      # Auto-provisioned Prometheus datasource
│   │       └── dashboards/dashboard_provider.yml
│   └── alertmanager/
│       └── alertmanager.yml.example            # Alert routing configuration template
│
└── docs/
    ├── ARCHITECTURE.md                         # 8 detailed Mermaid diagrams & specifications
    ├── IMPLEMENTATION_GUIDE.md                 # Complete reproduction guide
    ├── SECURITY.md                             # Threat model & DevSecOps posture
    ├── RUNBOOK_NFS.md                          # Day-2 NFS operational runbook
    ├── RUNBOOK_BACKUP_RESTORE.md               # S3 Backup & Disaster Recovery runbook
    ├── RUNBOOK_INCIDENT_DISASTER_RECOVERY.md   # P1 incident post-mortem & RCA
    └── TEST_RESULTS.md                         # Validation traceability matrix
```

---

## 6. Storage Lifecycle & DevSecOps Implementation

### 6.1 Safe Storage Discovery & LVM
To prevent accidental destruction of the OS root filesystem, the Ansible storage role detects the root partition (`findmnt -n -o SOURCE /`) and resolves its parent disk (`lsblk -no PKNAME`). It validates EBS volume metadata/serial, scans candidate disks, rejects any disk containing active mounts, and ensures only the unambiguous non-root EBS disk is provisioned into Volume Group `vg_storage`, carved into Logical Volume `lv_data`, formatted with XFS, and mounted to `/srv/nfs_share`.

### 6.2 NFSv4 Security & Privilege Escalation Mitigation
In `/etc/exports`, client access is restricted strictly to the internal storage subnet:
```text
/srv/nfs_share 10.0.2.0/24(rw,sync,no_subtree_check,root_squash)
```
* **`root_squash`**: Protects the storage server from privilege escalation. If client-side root writes files, the server kernel maps the request to `nobody:nogroup` (UID 65534). This behavior is automatically verified by `ansible/playbooks/validation.yml`.
* **`sync`**: Forces all file writes to commit to block storage before acknowledging RPC replies, ensuring zero data loss during power disruptions.

### 6.3 Client Mount Resilience
NFS clients mount the remote share with resilient flags in `/etc/fstab`:
```text
10.0.2.10:/srv/nfs_share  /mnt/nfs_share  nfs4  defaults,_netdev,nofail,hard,timeo=600,retrans=2  0 0
```
* `_netdev`: Prevents boot hangs by delaying mounting until network interfaces are up.
* `nofail`: Ensures the compute node boots cleanly even during storage maintenance windows.
* `hard`: Prevents silent data corruption during transient network hiccups by retrying I/O requests until acknowledged, rather than dropping writes.
* `timeo=600, retrans=2`: Configures standard 60-second timeout intervals and retransmission handling.

---

## 7. Disaster Recovery & Data Protection Workflow

```
[Live NFS Share] ──(xfs_freeze -f)──> [Quiesce Filesystem]
                                              │
                                              ▼
                                    [Take LVM Snapshot]
                                              │
                                              ▼
                                    [xfs_freeze -u (Unfreeze)]
                                              │
                                              ▼
                                    [Mount Snapshot ro,nouuid]
                                              │
                                              ▼
                                    [Generate SHA-256 Manifest]
                                              │
                                              ▼
                                    [Upload to Amazon S3 via AWS CLI]
                                              │
                                              ▼
                                    [Audit Remote S3 Checksum]
```

### Staged Restoration with Safety Cutover Gate
Unlike destructive restore scripts, `scripts/recovery/restore_from_s3.sh` downloads and unpacks backup archives into `/srv/nfs_restore_staging/`. It verifies the SHA-256 checksum against the S3 manifest. Only when an operator passes `--confirm-cutover` does it synchronize data to `/srv/nfs_share/` while preserving non-conflicting live files.

---

## 8. Deployment Quickstart

### Step 1: Provision Cloud Infrastructure
```bash
cd infrastructure/terraform/environments/lab
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your AWS key pair name
terraform init
terraform plan
terraform apply
```

### Step 2: Configure Nodes via Ansible
```bash
cd ../../../../ansible
ansible-galaxy collection install -r requirements.yml
cp inventory/hosts.example.ini inventory/hosts.ini
cp inventory/group_vars/all.yml.example inventory/group_vars/all.yml
# Fill in outputs from Terraform
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
ansible-playbook -i inventory/hosts.ini playbooks/monitoring.yml
```

### Step 3: Run Disaster Recovery & Observability
```bash
# On Storage Server:
export S3_BUCKET="<your-s3-bucket-name>"
sudo -E /opt/scripts/backup/backup_to_s3.sh
sudo -E /opt/scripts/backup/verify_backup.sh <TIMESTAMP>

# Access Grafana Dashboards:
# URL: http://<MANAGEMENT_NODE_PUBLIC_IP>:3000
```

### Step 4: Teardown
```bash
cd infrastructure/terraform/environments/lab
terraform destroy
```

---

## 9. Security, Cost & Limitations

* **Cost Optimization:** Uses minimal instance sizing (`t3.small` for monitoring, `t3.micro` for storage/client) and avoids NAT Gateways ($32/month) by leveraging public subnets with tight Security Groups. Expected run cost during active lab testing is under **$0.50/day**.
* **High Availability Distinction:** This architecture implements **Service Recovery and Disaster Recovery**, not active-active automatic clustering. In an outage, recovery is executed via staged restore.
* **Tested Status:** All code, configurations, playbooks, and shell scripts are **locally validated** for syntax and schema compliance. End-to-end integration is pending AWS execution.
