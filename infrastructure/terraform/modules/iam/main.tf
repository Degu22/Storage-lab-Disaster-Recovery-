# IAM Role for EC2 Instance Profile (Zero hardcoded credentials)
resource "aws_iam_role" "ec2_storage_dr_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ec2-role"
    Environment = var.environment
  }
}

# Attach AWS Systems Manager (SSM) Core policy for secure agent-based management without open inbound ports
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_storage_dr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Least-Privilege S3 Policy for Backup and Disaster Recovery
# DevSecOps Hardening: s3:DeleteObject is intentionally omitted so compromised
# instances cannot wipe existing backups. Retention is managed via S3 Lifecycle Rules.
resource "aws_iam_policy" "s3_backup_restore_policy" {
  name        = "${var.project_name}-s3-dr-policy"
  description = "Scoped permissions for S3 Disaster Recovery backups and restore operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListDRBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = var.s3_bucket_arn
      },
      {
        Sid    = "ReadWriteDRObjects"
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

resource "aws_iam_role_policy_attachment" "s3_dr_attach" {
  role       = aws_iam_role.ec2_storage_dr_role.name
  policy_arn = aws_iam_policy.s3_backup_restore_policy.arn
}

# Instance Profile to attach to EC2 instances
resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.ec2_storage_dr_role.name
}
