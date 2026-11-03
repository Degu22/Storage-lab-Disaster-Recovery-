output "instance_profile_name" {
  description = "Name of the IAM instance profile to attach to EC2 instances"
  value       = aws_iam_instance_profile.instance_profile.name
}

output "role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.ec2_storage_dr_role.arn
}
