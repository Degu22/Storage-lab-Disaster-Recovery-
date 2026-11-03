# Technical Architecture Specification: Enterprise Storage Service Lifecycle & Disaster Recovery Lab

## 1. Executive Summary

This architecture implements a centralized, enterprise-grade Linux shared storage service hosted on AWS, running on Ubuntu Server 24.04 LTS. It demonstrates the complete storage service lifecycle: infrastructure provisioning with Terraform, configuration automation via Ansible, secure multi-client NFSv4 access, disaster recovery with LVM snapshots and Amazon S3, and end-to-end observability using Prometheus and Grafana.

---

## 2. Mermaid Architecture Diagrams

### 2.1 Overall AWS Cloud Infrastructure
```mermaid
flowchart TD
    subgraph AWS_Cloud ["AWS Cloud (VPC: 10.0.0.0/16)"]
        IGW[Internet Gateway]
        
        subgraph Management_Subnet ["Management & Monitoring Subnet (10.0.1.0/24)"]
            Node_A["Management Node (Ubuntu 24.04 - t3.small)<br/>• Ansible Control Engine<br/>• Prometheus (:9090)<br/>• Grafana (:3000)<br/>• Alertmanager (:9093)"]
        end
        
        subgraph Storage_Subnet ["Storage & Compute Subnet (10.0.2.0/24)"]
            Node_B["NFS Storage Server (Ubuntu 24.04 - t3.micro)<br/>• LVM2 (vg_storage / lv_data)<br/>• XFS Filesystem (/srv/nfs_share)<br/>• NFSv4 Kernel Server<br/>• Node Exporter (:9100)"]
            Node_C["NFS Client Compute Node (Ubuntu 24.04 - t3.micro)<br/>• Mount: /mnt/nfs_share<br/>• Node Exporter (:9100)"]
            EBS_Data[("Dedicated EBS gp3 Data Volume<br/>(20 GiB, Encrypted)")]
            EBS_Data --- Node_B
        end
        
        subgraph S3_DR ["Independent Disaster Recovery Destination"]
            S3_Bucket[("Amazon S3 DR Bucket<br/>• Versioned<br/>• AES256 Encrypted<br/>• Block Public Access Active")]
        end
    end
    
    IGW --> Node_A
    Node_A -->|SSH Automation & Scrapes| Node_B
    Node_A -->|SSH Automation & Scrapes| Node_C
    Node_C -->|NFSv4 TCP:2049| Node_B
    Node_B -->|AWS CLI / IAM Role / HTTPS:443| S3_Bucket
```

### 2.2 NFS Client-to-Server Communication Flow
```mermaid
sequenceDiagram
    autonumber
    participant Client as NFS Client Node (/mnt/nfs_share)
    participant Kernel as Linux VFS Kernel
    participant Network as Storage Subnet (UFW Firewall)
    participant Server as NFS Server (/srv/nfs_share)
    participant Storage as LVM (XFS Filesystem)

    Client->>Kernel: I/O Read/Write Request
    Kernel->>Network: TCP Port 2049 (NFSv4.2 Compound RPC)
    Network->>Server: Ingress Allowed (10.0.2.0/24)
    Server->>Server: Validate /etc/exports (root_squash check)
    alt Client is root (UID 0)
        Server->>Server: Map UID 0 to nobody:nogroup (UID 65534)
    else Standard User
        Server->>Server: Preserve POSIX Client UID/GID
    end
    Server->>Storage: Direct I/O to XFS Block Layer
    Storage-->>Server: Disk Commit Acknowledged (sync flag)
    Server-->>Client: RPC Reply
```

### 2.3 Terraform Provisioning Flow
```mermaid
flowchart LR
    A[terraform plan] --> B[Module: Networking<br/>VPC, Subnets, IGW, Route Tables]
    B --> C[Module: Security<br/>Security Groups: Mgmt, Storage, Client]
    C --> D[Module: Storage<br/>EBS gp3 Volume & S3 DR Bucket]
    D --> E[Module: IAM<br/>EC2 Role, Instance Profile, S3 DR Policy]
    E --> F[Module: Compute<br/>3x EC2 Ubuntu 24.04 Instances + EBS Attachment]
    F --> G[Outputs<br/>IP Addresses & Inventory Helper]
```

### 2.4 Ansible Configuration Pipeline
```mermaid
flowchart TD
    Site[site.yml] --> Common[Role: common<br/>Base packages, Chrony NTP, UFW Baseline]
    Site --> NodeExp[Role: node_exporter<br/>Install binary & open port 9100]
    Site --> Storage[Role: storage<br/>Identify disk, LVM vg/lv, format XFS, mount /srv/nfs_share]
    Site --> NFSServer[Role: nfs_server<br/>Configure /etc/exports, root_squash, UFW port 2049]
    Site --> NFSClient[Role: nfs_client<br/>Install nfs-common, persistent /etc/fstab, mount /mnt/nfs_share]
    Site --> Validate[Playbook: validation.yml<br/>Verify mount, write test, assert root_squash UID mapping]
```

### 2.5 Backup-to-S3 Disaster Recovery Workflow
```mermaid
flowchart TD
    Start([Backup Job Triggered]) --> Step1[1. Verify /srv/nfs_share is mounted]
    Step1 --> Step2[2. Quiesce XFS Filesystem: xfs_freeze -f]
    Step2 --> Step3[3. Create LVM Point-in-Time Snapshot: lvcreate -s]
    Step3 --> Step4[4. Unfreeze Filesystem: xfs_freeze -u]
    Step4 --> Step5[5. Mount Snapshot Read-Only: /mnt/snapshot_temp]
    Step5 --> Step6[6. Compress Archive: tar -czf]
    Step6 --> Step7[7. Calculate Cryptographic SHA-256 Checksum]
    Step7 --> Step8[8. Upload Archive & Manifest to Amazon S3 via AWS CLI]
    Step8 --> Step9[9. Validate S3 Upload & Compare Checksums]
    Step9 --> Step10[10. Unmount & Destroy Snapshot: lvremove]
    Step10 --> End([Backup Verified & Complete])
```

### 2.6 Disaster Recovery Staged Restore Workflow
```mermaid
flowchart TD
    Start([Disaster Event / Restore Triggered]) --> Step1[1. Download Archive & Manifest from S3 to Staging Area]
    Step1 --> Step2[2. Validate SHA-256 Hash of Downloaded Archive]
    Step2 -->|Hash Mismatch| Abort([ABORT: Corrupt Archive])
    Step2 -->|Hash Matches| Step3[3. Extract into /srv/nfs_restore_staging]
    Step3 --> Step4[4. Audit File Permissions & Ownership]
    Step4 --> Step5{5. Controlled Cutover Gate:<br/>--confirm-cutover passed?}
    Step5 -->|No| Standby([STAGING COMPLETE: Awaiting Ops Approval])
    Step5 -->|Yes| Step6[6. Temporarily Unexport Live NFS Share]
    Step6 --> Step7[7. Rsync Staged Data to Live Directory with Pre-Restore Backup]
    Step7 --> Step8[8. Re-Export NFS Share & Restore SELinux/Permissions]
    Step8 --> Step9[9. Measure Elapsed Time: Record Achieved RTO]
    Step9 --> End([Service Restored & Verified])
```

### 2.7 Observability & Metric Scraping Architecture
```mermaid
flowchart LR
    subgraph Management_Node ["Management Node"]
        Prometheus[Prometheus Server :9090]
        Grafana[Grafana Dashboard :3000]
        Alertmanager[Alertmanager :9093]
        Prometheus --> Grafana
        Prometheus --> Alertmanager
    end

    subgraph Storage_Node ["NFS Storage Server"]
        NodeExp1[Node Exporter :9100]
        NFSD[NFS Kernel Metrics]
        LVM_Metrics[Filesystem & Disk I/O]
        LVM_Metrics --> NodeExp1
        NFSD --> NodeExp1
    end

    subgraph Client_Node ["NFS Client Node"]
        NodeExp2[Node Exporter :9100]
        ClientMount[NFS Mountstats]
        ClientMount --> NodeExp2
    end

    Prometheus -->|Pull Metrics Every 15s| NodeExp1
    Prometheus -->|Pull Metrics Every 15s| NodeExp2
```

### 2.8 Failure Detection and Incident Response Workflow
```mermaid
flowchart TD
    A[Failure Simulated: e.g. Disk-Fill >90% or NFS Crash] --> B[Prometheus Evaluates Rule]
    B -->|Condition Met for >2m| C[Alertmanager Fires P1 Alert]
    C --> D[Engineer Runs storage_health_check.sh]
    D --> E[Isolate Cause: Volume Full or Daemon Down]
    E --> F[Run Remediation Runbook or restore_from_s3.sh]
    F --> G[Run reset_lab.sh & validation.yml]
    G --> H[Prometheus Auto-Resolves Alert]
```

---

## 3. Network & Security Design

1. **Subnet Segmentation:**
   * `Management Subnet (10.0.1.0/24)`: Houses monitoring and operational tooling.
   * `Storage Subnet (10.0.2.0/24)`: Dedicated to data traffic between compute clients and storage servers.
2. **Security Groups:**
   * Port 2049 (NFSv4) is strictly restricted to internal subnets.
   * Management ports (22, 3000, 9090) are constrained to approved administrative ingress CIDRs.
   * Port 9100 (Node Exporter) is strictly restricted to the Management subnet.
3. **IAM Role Separation & Least Privilege:**
   * No static AWS access keys are deployed to instances. Roles are strictly decoupled per node responsibility:
     * **Management Node:** Scoped strictly to AWS Systems Manager (`AmazonSSMManagedInstanceCore`).
     * **Client Node:** Scoped strictly to AWS Systems Manager (`AmazonSSMManagedInstanceCore`).
     * **NFS Storage Server:** Scoped to SSM Core plus a dedicated least-privilege S3 policy (`s3:PutObject`, `s3:GetObject`, `s3:ListBucket`). `s3:DeleteObject` is intentionally omitted for immutable ransomware defense.
4. **DevSecOps Root Squashing & Mount Hardening:**
   * By default, client-side root accounts are squashed to `nobody:nogroup` on Ubuntu 24.04, neutralizing remote privilege escalation threats. Client mounts enforce `hard,timeo=600,retrans=2` to ensure write integrity.
5. **Access Architecture (Option B - Restricted SSH + SSM):**
   * Ansible configuration automation runs from the Management Node (`10.0.1.10`) targeting private Storage (`10.0.2.10`) and Client (`10.0.2.20`) nodes over internal SSH (port 22). Security groups restrict port 22 on private instances exclusively to `management_sg`.
   * Out-of-band administrative access is retained via AWS Systems Manager (`AmazonSSMManagedInstanceCore` on all three IAM roles).
6. **Private Subnet Connectivity & S3 Gateway VPC Endpoint:**
   * Storage and Client nodes reside in private subnets. S3 backup and restore operations traverse an AWS Gateway VPC Endpoint (`com.amazonaws.<region>.s3`) associated with the VPC route table at zero cost, never traversing the public internet.
   * In a temporary lab environment, to avoid AWS NAT Gateway ($32+/mo) and SSM Interface Endpoint ($21+/mo) costs, `assign_public_ip_to_storage` can be toggled to `true` during bootstrap to allow outbound package updates (`apt-get`) and direct SSM Session Manager access. In both modes, inbound security groups block all unauthorized traffic.
7. **Consistency Boundaries (Filesystem vs. Application):**
   * LVM snapshotting with `xfs_freeze -f` guarantees **Filesystem-Level Consistency** (VFS journal flushed, dirty blocks written). It does NOT guarantee **Application-Level Consistency** for active ACID databases (e.g. MySQL, PostgreSQL) unless application quiescing hooks (`FLUSH TABLES WITH READ LOCK`) are executed prior to freeze.
