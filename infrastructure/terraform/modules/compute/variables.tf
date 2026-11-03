variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "management_instance_type" {
  description = "Instance type for Management & Monitoring (Prometheus/Grafana recommended t3.small with 2GB RAM)"
  type        = string
  default     = "t3.small"
}

variable "storage_instance_type" {
  description = "Instance type for NFS Storage Server"
  type        = string
  default     = "t3.micro"
}

variable "client_instance_type" {
  description = "Instance type for NFS Client compute node"
  type        = string
  default     = "t3.micro"
}

variable "ssh_key_name" {
  description = "Name of the existing AWS Key Pair to attach for SSH access"
  type        = string
}

variable "management_subnet_id" {
  description = "Subnet ID for Management Node"
  type        = string
}

variable "storage_subnet_id" {
  description = "Subnet ID for Storage and Client Nodes"
  type        = string
}

variable "management_sg_id" {
  description = "Security Group ID for Management Node"
  type        = string
}

variable "storage_server_sg_id" {
  description = "Security Group ID for Storage Server"
  type        = string
}

variable "client_sg_id" {
  description = "Security Group ID for Client Node"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile name with SSM and S3 permissions"
  type        = string
}

variable "nfs_ebs_volume_id" {
  description = "EBS volume ID to attach to the Storage Server"
  type        = string
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GiB"
  type        = number
  default     = 10
}
