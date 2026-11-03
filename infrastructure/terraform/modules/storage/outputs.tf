output "s3_bucket_name" {
  description = "Name of the S3 Disaster Recovery bucket"
  value       = aws_s3_bucket.dr_bucket.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 Disaster Recovery bucket"
  value       = aws_s3_bucket.dr_bucket.arn
}

output "ebs_volume_id" {
  description = "ID of the dedicated NFS EBS data volume"
  value       = aws_ebs_volume.nfs_data_volume.id
}
