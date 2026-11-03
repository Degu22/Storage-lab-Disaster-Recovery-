# Security Specification & DevSecOps Architecture

## 1. Threat Modeling & Attack Vectors

| Attack Vector | Threat Description | Implemented Countermeasure |
| :--- | :--- | :--- |
| **Privilege Escalation** | Rogue or compromised client root user attempts to overwrite storage server system files. | **NFS `root_squash`**: Client root (UID 0) is mapped to unprivileged user `nobody:nogroup` (UID 65534). Validated via automated Ansible assertion. |
| **Data Exfiltration** | Unauthorized external entity attempts to read S3 backup archives. | **S3 Block Public Access**: All 4 public access blocks enabled; bucket policy restricts access strictly to EC2 IAM Role. |
| **Data at Rest Interception** | Physical disk compromise or unencrypted snapshots. | **Full Encryption at Rest**: AWS EBS gp3 volumes encrypted via AWS KMS default keys; S3 buckets encrypted with AES256. |
| **Lateral Network Movement** | Attacker compromises a web workload and attempts to access the NFS storage layer. | **Network Segmentation & Security Groups**: NFS port 2049 is dropped at the AWS Security Group and OS UFW level for all traffic outside the dedicated internal subnet (`10.0.2.0/24`). |
| **Data Poisoning / Corruption** | Silent disk bit-rot or malicious file alteration during backup/restore. | **Cryptographic SHA-256 Manifest**: Every backup generates a pre-upload SHA-256 checksum, audited remotely before restore cutover. |
| **Credential Compromise** | Hardcoded AWS credentials in scripts or GitHub repository. | **Zero Static Credentials**: 100% of AWS CLI operations rely on temporary STS credentials provided by EC2 IAM Instance Profiles. |

---

## 2. DevSecOps Principles in Practice

1. **Shift-Left Security:**
   * Automated assertions (`ansible/playbooks/validation.yml`) run immediately after provisioning to programmatically confirm security postures before workloads mount storage.
2. **Principle of Least Privilege & Ransomware Protection:**
   * IAM policies are explicitly scoped to the specific S3 bucket ARN, and `s3:DeleteObject` is intentionally **omitted** so that a compromised EC2 host cannot delete existing backup history. Data lifecycle expiration is strictly handled by S3 Lifecycle rules:
     ```json
     {
       "Action": ["s3:PutObject", "s3:GetObject"],
       "Resource": "arn:aws:s3:::storage-dr-backup-XXXX/*"
     }
     ```
3. **Defense-in-Depth:**
   * Dual-layered firewalls: AWS Security Groups at the hypervisor level + Ubuntu native `ufw` at the operating system level.
