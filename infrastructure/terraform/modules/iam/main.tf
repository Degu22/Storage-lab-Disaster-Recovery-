# Common EC2 Assume Role Policy document
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ==============================================================================
# 1. Management Node IAM Role & Profile (SSM Core Only)
# ==============================================================================
resource "aws_iam_role" "management_role" {
  name               = "${var.project_name}-management-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name        = "${var.project_name}-management-role"
    Environment = var.environment
    Tier        = "Management"
  }
}

resource "aws_iam_role_policy_attachment" "management_ssm" {
  role       = aws_iam_role.management_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "management_instance_profile" {
  name = "${var.project_name}-management-instance-profile"
  role = aws_iam_role.management_role.name
}

# ==============================================================================
# 2. NFS Client Node IAM Role & Profile (SSM Core Only)
# ==============================================================================
resource "aws_iam_role" "client_role" {
  name               = "${var.project_name}-client-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name        = "${var.project_name}-client-role"
    Environment = var.environment
    Tier        = "Client"
  }
}

resource "aws_iam_role_policy_attachment" "client_ssm" {
  role       = aws_iam_role.client_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "client_instance_profile" {
  name = "${var.project_name}-client-instance-profile"
  role = aws_iam_role.client_role.name
}

# ==============================================================================
# 3. NFS Storage Server IAM Role & Profile (SSM Core + Scoped S3 DR Permissions)
# ==============================================================================
resource "aws_iam_role" "storage_server_role" {
  name               = "${var.project_name}-storage-server-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name        = "${var.project_name}-storage-server-role"
    Environment = var.environment
    Tier        = "Storage"
  }
}

resource "aws_iam_role_policy_attachment" "storage_server_ssm" {
  role       = aws_iam_role.storage_server_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Least-Privilege S3 Policy for Backup & Restore
# DevSecOps Hardening:
# - Bucket-level operations (ListBucket, GetBucketLocation) applied strictly to bucket ARN
# - Object-level operations (PutObject, GetObject) applied strictly to bucket objects
# - s3:DeleteObject is intentionally OMITTED for ransomware defense; retention is managed via S3 Lifecycle
resource "aws_iam_policy" "storage_s3_dr_policy" {
  name        = "${var.project_name}-storage-s3-dr-policy"
  description = "Scoped permissions for S3 Disaster Recovery backups and restore operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BucketLevelListAndLocation"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = var.s3_bucket_arn
      },
      {
        Sid    = "ObjectLevelPutAndGet"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = "${var.s3_bucket_arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "storage_s3_attach" {
  role       = aws_iam_role.storage_server_role.name
  policy_arn = aws_iam_policy.storage_s3_dr_policy.arn
}

resource "aws_iam_instance_profile" "storage_server_instance_profile" {
  name = "${var.project_name}-storage-server-instance-profile"
  role = aws_iam_role.storage_server_role.name
}
