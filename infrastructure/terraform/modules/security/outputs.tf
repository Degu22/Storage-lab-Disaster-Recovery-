output "management_sg_id" {
  description = "Security Group ID for Management Node"
  value       = aws_security_group.management_sg.id
}

output "storage_server_sg_id" {
  description = "Security Group ID for Storage Server"
  value       = aws_security_group.storage_server_sg.id
}

output "client_sg_id" {
  description = "Security Group ID for NFS Client Node"
  value       = aws_security_group.client_sg.id
}
