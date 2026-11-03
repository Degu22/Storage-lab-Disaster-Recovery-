# Random ID to guarantee global S3 bucket name uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# 1. Independent S3 Disaster Recovery Destination
resource "aws_s3_bucket" "dr_bucket" {
  bucket        = "${var.s3_bucket_prefix}-${random_id.bucket_suffix.hex}"
  force_destroy = false # Prevent accidental deletion if backups exist

  tags = {
    Name        = "${var.project_name}-dr-bucket"
    Environment = var.environment
    Purpose     = "Disaster Recovery Storage"
  }
}

# S3 Block Public Access (Enforcing private storage security)
resource "aws_s3_bucket_public_access_block" "dr_bucket_pab" {
  bucket = aws_s3_bucket.dr_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Versioning (Protects backup manifests and archives from accidental overwrites)
resource "aws_s3_bucket_versioning" "dr_bucket_versioning" {
  bucket = aws_s3_bucket.dr_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Default Server-Side Encryption (AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "dr_bucket_crypto" {
  bucket = aws_s3_bucket.dr_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Lifecycle Rule for Cost-Conscious Retention (Expire noncurrent backup versions after 30 days)
resource "aws_s3_bucket_lifecycle_configuration" "dr_bucket_lifecycle" {
  bucket = aws_s3_bucket.dr_bucket.id

  rule {
    id     = "expire-old-dr-backups"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# 2. Dedicated EBS Block Storage Volume for NFS Server (LVM pool)
resource "aws_ebs_volume" "nfs_data_volume" {
  availability_zone = var.availability_zone
  size              = var.ebs_volume_size
  type              = var.ebs_volume_type
  encrypted         = true

  tags = {
    Name        = "${var.project_name}-nfs-data-ebs"
    Environment = var.environment
    Tier        = "LVM Data Pool"
  }
}
