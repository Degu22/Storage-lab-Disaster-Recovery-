output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "management_subnet_id" {
  description = "ID of the management subnet"
  value       = aws_subnet.management.id
}

output "storage_subnet_id" {
  description = "ID of the storage subnet"
  value       = aws_subnet.storage.id
}

output "management_subnet_cidr" {
  description = "CIDR of the management subnet"
  value       = aws_subnet.management.cidr_block
}

output "storage_subnet_cidr" {
  description = "CIDR of the storage subnet"
  value       = aws_subnet.storage.cidr_block
}
