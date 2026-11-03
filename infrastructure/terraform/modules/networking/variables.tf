variable "project_name" {
  description = "Project prefix for resource naming and tagging"
  type        = string
  default     = "storage-dr-lab"
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "lab"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "management_subnet_cidr" {
  description = "CIDR block for the management and monitoring subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "storage_subnet_cidr" {
  description = "CIDR block for the storage and compute client subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Target AWS availability zone for single-AZ lab deployment"
  type        = string
  default     = "eu-north-1a"
}

variable "assign_public_ip_to_storage" {
  description = "Whether to assign public IPs to storage/client nodes. Defaults to false for strict private isolation. When false, S3 operates privately via the S3 Gateway VPC Endpoint. For temporary labs without NAT Gateway ($32+/mo), setting to true enables outbound apt package downloads and direct SSM access while security groups block 100% of inbound public traffic."
  type        = bool
  default     = false
}
