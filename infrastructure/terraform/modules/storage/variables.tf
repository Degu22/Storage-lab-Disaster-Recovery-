variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone matching the storage server EC2 instance"
  type        = string
}

variable "ebs_volume_size" {
  description = "Size in GiB for the dedicated NFS LVM storage volume"
  type        = number
  default     = 20
}

variable "ebs_volume_type" {
  description = "EBS volume type (gp3 recommended for cost/performance predictability)"
  type        = string
  default     = "gp3"
}

variable "s3_bucket_prefix" {
  description = "Prefix for the S3 disaster recovery bucket name"
  type        = string
  default     = "storage-dr-backup"
}
