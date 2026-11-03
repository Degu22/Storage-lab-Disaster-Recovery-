terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Note on State Management:
  # For local learning and interview demonstration, local state is used by default.
  # For multi-engineer teams, configure an S3 backend with DynamoDB state locking.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Enterprise-Storage-DR-Lab"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
