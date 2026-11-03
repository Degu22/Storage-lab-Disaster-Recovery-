variable "aws_region" {
  description = "AWS region for deployment (e.g., eu-north-1 for Stockholm or us-east-1)"
  type        = string
  default     = "eu-north-1"
}

variable "availability_zone" {
  description = "Target availability zone"
  type        = string
  default     = "eu-north-1a"
}

variable "project_name" {
  description = "Project naming prefix"
  type        = string
  default     = "storage-dr-lab"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "lab"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "management_subnet_cidr" {
  description = "Management subnet CIDR block"
  type        = string
  default     = "10.0.1.0/24"
}

variable "storage_subnet_cidr" {
  description = "Storage and Client subnet CIDR block"
  type        = string
  default     = "10.0.2.0/24"
}

variable "admin_ingress_cidrs" {
  description = "Explicit list of authorized IP CIDRs allowed to access SSH, Prometheus (:9090), and Grafana (:3000). Must be specified (e.g. [\"203.0.113.50/32\"])."
  type        = list(string)
}

variable "ssh_key_name" {
  description = "Name of an existing AWS EC2 Key Pair for SSH access"
  type        = string
}

variable "management_instance_type" {
  description = "Instance type for Management node (t3.small recommended for Prometheus + Grafana)"
  type        = string
  default     = "t3.small"
}

variable "storage_instance_type" {
  description = "Instance type for NFS Storage Server"
  type        = string
  default     = "t3.micro"
}

variable "client_instance_type" {
  description = "Instance type for NFS Client node"
  type        = string
  default     = "t3.micro"
}

variable "ebs_volume_size" {
  description = "Dedicated EBS volume size in GiB for NFS LVM data pool"
  type        = number
  default     = 20
}

variable "backup_retention_days" {
  description = "Days to retain current S3 backup archives before automated expiration"
  type        = number
  default     = 30
}

variable "noncurrent_version_retention_days" {
  description = "Days to retain noncurrent S3 backup versions before permanent deletion"
  type        = number
  default     = 14
}

variable "assign_public_ip_to_storage" {
  description = "Assign public IPs to storage/client nodes. Defaults to false for strict private isolation. When false, S3 operates privately via the S3 Gateway VPC Endpoint. For temporary labs without NAT Gateway ($32+/mo), setting to true enables outbound apt package downloads and direct SSM access while security groups block 100% of inbound public traffic."
  type        = bool
  default     = false
}
