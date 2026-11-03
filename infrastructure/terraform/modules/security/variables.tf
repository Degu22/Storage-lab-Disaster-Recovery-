variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "admin_ingress_cidrs" {
  description = "Explicit list of authorized external IP CIDRs for administrative SSH, Grafana (:3000), and Prometheus (:9090). Must not be 0.0.0.0/0 in production."
  type        = list(string)
}

variable "management_subnet_cidr" {
  description = "CIDR block of management subnet for internal metrics scraping and SSH bastion access"
  type        = string
}

variable "storage_subnet_cidr" {
  description = "CIDR block of storage subnet for NFS client access"
  type        = string
}
