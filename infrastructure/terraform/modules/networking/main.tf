resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Subnet 1: Management & Monitoring Subnet (Node A)
resource "aws_subnet" "management" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.management_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-management-subnet"
    Environment = var.environment
    Tier        = "Management"
  }
}

# Subnet 2: Storage & Client Subnet (Nodes B & C)
resource "aws_subnet" "storage" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.storage_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = var.assign_public_ip_to_storage

  tags = {
    Name        = "${var.project_name}-storage-subnet"
    Environment = var.environment
    Tier        = "Storage"
  }
}

# Route table with direct Internet Gateway route for management
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "management_assoc" {
  subnet_id      = aws_subnet.management.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "storage_assoc" {
  subnet_id      = aws_subnet.storage.id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------------------
# S3 Gateway VPC Endpoint
# Enables direct, private, zero-cost communication to Amazon S3 for backups/restores
# without traversing the public internet or incurring NAT Gateway charges.
# ------------------------------------------------------------------------------
data "aws_region" "current" {}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id]

  tags = {
    Name        = "${var.project_name}-s3-gateway-endpoint"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
