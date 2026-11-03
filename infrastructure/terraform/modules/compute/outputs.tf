output "management_private_ip" {
  description = "Private IP of Management Node"
  value       = aws_instance.management.private_ip
}

output "management_public_ip" {
  description = "Public IP of Management Node (for SSH and Grafana access)"
  value       = aws_instance.management.public_ip
}

output "storage_server_private_ip" {
  description = "Private IP of Storage Server"
  value       = aws_instance.storage_server.private_ip
}

output "storage_server_public_ip" {
  description = "Public IP of Storage Server (if assigned)"
  value       = aws_instance.storage_server.public_ip
}

output "client_private_ip" {
  description = "Private IP of Client Node"
  value       = aws_instance.client.private_ip
}

output "client_public_ip" {
  description = "Public IP of Client Node (if assigned)"
  value       = aws_instance.client.public_ip
}

output "storage_server_id" {
  description = "Instance ID of Storage Server"
  value       = aws_instance.storage_server.id
}
