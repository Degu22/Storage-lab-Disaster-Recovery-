# Test Results & Validation Traceability Matrix

This document tracks all formal test cases across Infrastructure, Storage, Automation, Backup/DR, Monitoring, and Security.

Status Definitions:
* `[Locally Validated]`: Passed local static syntax, linting, schema, or unit validation.
* `[Pending Live AWS Testing]`: Requires deployed AWS infrastructure to run end-to-end integration tests.

---

## 1. Test Execution Matrix

| Test ID | Test Category | Objective | Verification Method | Status | Evidence / Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TEST-IAC-01** | Infrastructure | Validate HCL2 syntax and formatting of Terraform modules. | `terraform fmt` / static HCL review | **`[Locally Validated]`** | All modules (`networking`, `security`, `iam`, `storage`, `compute`) formatted cleanly. |
| **TEST-IAC-02** | Infrastructure | Validate Terraform variable type constraints and defaults. | HCL variable static check | **`[Locally Validated]`** | All variables typed and default values assigned where required. |
| **TEST-ANS-01** | Automation | Validate YAML syntax across all playbooks and roles. | Python YAML Parser (`yaml.safe_load`) | **`[Locally Validated]`** | `site.yml`, `monitoring.yml`, `validation.yml`, and all roles parsed with 0 syntax errors. |
| **TEST-ANS-02** | Automation | Verify Ansible role idempotency. | Double-run execution | `[Pending Live AWS Testing]` | Scheduled for live EC2 execution. |
| **TEST-STR-01** | Storage | Verify safe EBS device identification (protecting root disk). | Root partition check (`findmnt`) and parent disk exclusion (`lsblk -no PKNAME`) | **`[Locally Validated]`** | Tested logic fails execution if candidate matches root disk or has mounted partitions. |
| **TEST-STR-02** | Storage | Verify LVM volume creation and XFS formatting. | Live block device creation | `[Pending Live AWS Testing]` | Scheduled on EBS volume attachment. |
| **TEST-IAM-02** | Security | Verify IAM role separation between Management, Storage, and Client. | Terraform IAM module audit | **`[Locally Validated]`** | Distinct instance profiles generated; S3 permissions restricted strictly to Storage Server. |
| **TEST-S3-01** | Backup & DR | Verify S3 Lifecycle Configuration rules. | Terraform storage module audit | **`[Locally Validated]`** | Configures current expiration (30d), noncurrent expiration (14d), and multipart abort (7d). |
| **TEST-NFS-01** | NFS Protocol | Validate NFSv4 export configuration with `root_squash`. | Export configuration audit | **`[Locally Validated]`** | `/etc/exports` includes `root_squash,sync,no_subtree_check`. |
| **TEST-NFS-02** | DevSecOps | Programmatically assert client root cannot write UID 0. | `ansible/playbooks/validation.yml` | `[Pending Live AWS Testing]` | Asserts client root files are mapped to UID != 0. |
| **TEST-NFS-03** | Reliability | Enforce `hard` NFS mount options to eliminate dropped writes. | Ansible client role check | **`[Locally Validated]`** | Client mount verified to use `hard,timeo=600,retrans=2`. |
| **TEST-BKP-01** | Backup & DR | Verify Bash syntax and error handling in backup scripts. | `bash -n` syntax check | **`[Locally Validated]`** | All scripts passed `set -euo pipefail` static check. |
| **TEST-BKP-02** | Backup & DR | Cryptographic SHA-256 pre/post upload integrity check. | Hash audit script | `[Pending Live AWS Testing]` | Validates bit-level consistency against S3 manifest. |
| **TEST-REC-01** | Backup & DR | Verify staging isolation prior to live cutover. | Safety gate check (`--confirm-cutover`) | **`[Locally Validated]`** | Refuses live cutover unless explicit flag is passed. |
| **TEST-MON-01** | Observability | Validate PromQL alert rules syntax and thresholds. | YAML schema validation | **`[Locally Validated]`** | Evaluates storage warning at 80%, critical at 90%, latency at >50ms. |
| **TEST-MON-02** | Observability | Validate Grafana dashboard JSON schema. | Python JSON validator | **`[Locally Validated]`** | `storage_overview.json` schema validated cleanly. |
| **TEST-SEC-01** | Security | Secret audit to guarantee no private keys or credentials. | Local regex & secret pattern audit | **`[Locally Validated]`** | Zero AWS keys, private keys, or passwords in repository. |
