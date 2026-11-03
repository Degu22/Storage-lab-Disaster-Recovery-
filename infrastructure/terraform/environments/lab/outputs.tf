output "s3_dr_bucket_name" {
  description = "Name of the S3 Disaster Recovery bucket for backups"
  value       = module.storage.s3_bucket_name
}

output "management_node_public_ip" {
  description = "Public IP of Management Node (Ansible, Grafana :3000, Prometheus :9090)"
  value       = module.compute.management_public_ip
}

output "storage_server_private_ip" {
  description = "Internal Private IP of NFS Storage Server"
  value       = module.compute.storage_server_private_ip
}

output "storage_server_public_ip" {
  description = "Public IP of Storage Server (for direct SSH access during lab)"
  value       = module.compute.storage_server_public_ip
}

output "nfs_client_private_ip" {
  description = "Internal Private IP of NFS Client Node"
  value       = module.compute.client_private_ip
}

output "nfs_client_public_ip" {
  description = "Public IP of NFS Client Node (for direct SSH access during lab)"
  value       = module.compute.client_public_ip
}

output "grafana_url" {
  description = "Web URL for Grafana Monitoring Dashboards"
  value       = "http://${module.compute.management_public_ip}:3000"
}

output "prometheus_url" {
  description = "Web URL for Prometheus Server UI"
  value       = "http://${module.compute.management_public_ip}:9090"
}

output "ansible_inventory_helper" {
  description = "Generated Ansible Inventory snippet for quick configuration"
  value       = <<EOT
[management_servers]
mgmt-01 ansible_host=${module.compute.management_public_ip} private_ip=${module.compute.management_private_ip}

[storage_servers]
nfs-server-01 ansible_host=${module.compute.storage_server_public_ip} private_ip=${module.compute.storage_server_private_ip}

[storage_clients]
nfs-client-01 ansible_host=${module.compute.client_public_ip} private_ip=${module.compute.client_private_ip}
EOT
}
