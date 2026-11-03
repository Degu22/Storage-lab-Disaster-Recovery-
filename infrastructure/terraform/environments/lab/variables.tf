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
  description = "List of authorized IP CIDRs allowed to access SSH, Prometheus (:9090), and Grafana (:3000)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Change to your actual IP/32 in production
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

variable "assign_public_ip_to_storage" {
  description = "Assign public IPs to storage/client nodes for lab accessibility without NAT Gateway"
  type        = bool
  default     = true
}
