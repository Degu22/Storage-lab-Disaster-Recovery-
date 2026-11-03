# Implementation & Reproduction Guide: Enterprise Storage Service & DR Lab

This guide provides the complete, reproducible, step-by-step instructions for deploying, configuring, testing, and cleaning up the lab.

---

## 1. Prerequisites

Before beginning deployment, ensure the following prerequisites are met:
1. **AWS Account** with sufficient permissions to create VPCs, EC2 instances, EBS volumes, S3 buckets, and IAM roles.
2. **AWS Key Pair** created in your target region (e.g. `storage-lab-key`).
3. **Terraform CLI (>= 1.5.0)** and **AWS CLI (v2)** installed locally.
4. **Ansible (>= 2.15)** installed on your management machine or Ansible control node.

---

## 2. Phase 1: Infrastructure Provisioning (Terraform)

```bash
# 1. Navigate to the lab environment directory
cd infrastructure/terraform/environments/lab

# 2. Copy the variable template
cp terraform.tfvars.example terraform.tfvars

# 3. Edit terraform.tfvars with your specific AWS Key Pair name and target region
# e.g., ssh_key_name = "your-actual-key-pair"

# 4. Initialize Terraform and validate configuration
terraform init
terraform validate

# 5. Review the execution plan
terraform plan

# 6. Apply infrastructure (Requires explicit human review)
terraform apply
```

After provisioning completes, copy the generated outputs:
* `s3_dr_bucket_name`
* `management_node_public_ip`
* `storage_server_public_ip` & `storage_server_private_ip`
* `nfs_client_public_ip` & `nfs_client_private_ip`

---

## 3. Phase 2: Configuration Management (Ansible)

```bash
# 1. Navigate to the Ansible directory
cd ../../../../ansible

# 2. Install required Ansible collections
ansible-galaxy collection install -r requirements.yml

# 3. Copy inventory and group variable examples
cp inventory/hosts.example.ini inventory/hosts.ini
cp inventory/group_vars/all.yml.example inventory/group_vars/all.yml

# 3. Update inventory/hosts.ini with the IP addresses from Terraform outputs
# 4. Update inventory/group_vars/all.yml with the S3 bucket name from Terraform outputs

# 5. Run syntax check across all playbooks
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --syntax-check

# 6. Execute master provisioning playbook
ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# 7. Configure Monitoring & Observability stack
ansible-playbook -i inventory/hosts.ini playbooks/monitoring.yml
```

---

## 4. Phase 3: Backup & Disaster Recovery Execution

SSH into the **NFS Storage Server**:
```bash
# 1. Export S3 bucket name from Terraform output
export S3_BUCKET="your-terraform-generated-bucket-name"

# 2. Execute consistent LVM snapshot backup to S3
sudo S3_BUCKET="${S3_BUCKET}" /opt/scripts/backup/backup_to_s3.sh

# 3. Audit and verify backup archive integrity from S3
# Use the timestamp printed by the backup script (e.g. 20261103_150000)
sudo S3_BUCKET="${S3_BUCKET}" /opt/scripts/backup/verify_backup.sh 20261103_150000

# 4. Test safe staging restoration (Safety gate: does not overwrite live data)
sudo S3_BUCKET="${S3_BUCKET}" /opt/scripts/recovery/restore_from_s3.sh 20261103_150000

# 5. Execute production cutover gate
sudo S3_BUCKET="${S3_BUCKET}" /opt/scripts/recovery/restore_from_s3.sh 20261103_150000 --confirm-cutover

# 6. Validate restored data
sudo /opt/scripts/recovery/validate_restore.sh
```

---

## 5. Phase 4: Observability & Failure Drills

1. **Access Grafana Dashboard:**
   * Open `http://<MANAGEMENT_NODE_PUBLIC_IP>:3000` in your browser.
   * Default credentials: `admin` / `admin` (prompted to reset on first login).
   * Open the pre-provisioned dashboard: **"Enterprise Storage Service & Health Overview"**.
2. **Access Prometheus UI:**
   * Open `http://<MANAGEMENT_NODE_PUBLIC_IP>:9090`.
   * Check **Status -> Targets** (Verify all 3 nodes report state `UP`).
   * Check **Alerts** (Verify 5 rules are loaded).
3. **Execute Failure Scenarios:**
   ```bash
   # On NFS Storage Server:
   # Scenario A: Capacity Warning Trigger (>80%)
   sudo /opt/scripts/failure-simulation/simulate_capacity_warning.sh
   # Observe alert firing in Prometheus / Grafana gauge turning yellow/red.

   # Reset environment to healthy state
   sudo /opt/scripts/failure-simulation/reset_lab.sh
   ```

---

## 6. Phase 5: Complete Teardown & AWS Cost Cleanup

When finished testing, cleanly destroy all AWS resources to avoid incurring charges:
```bash
cd infrastructure/terraform/environments/lab

# Destroy all cloud resources (Review plan carefully before confirming)
terraform destroy
```
Verify that no residual EBS volumes, snapshots, or EC2 instances remain in the AWS Console.
