output "management_instance_profile_name" {
  description = "Name of the IAM instance profile for Management Node (SSM Core)"
  value       = aws_iam_instance_profile.management_instance_profile.name
}

output "storage_server_instance_profile_name" {
  description = "Name of the IAM instance profile for Storage Server (SSM Core + Scoped S3 DR)"
  value       = aws_iam_instance_profile.storage_server_instance_profile.name
}

output "client_instance_profile_name" {
  description = "Name of the IAM instance profile for Client Node (SSM Core)"
  value       = aws_iam_instance_profile.client_instance_profile.name
}
