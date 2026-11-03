# 1. Security Group for Management & Monitoring Node (Node A)
resource "aws_security_group" "management_sg" {
  name        = "${var.project_name}-management-sg"
  description = "Security group for Management, Ansible, Prometheus, and Grafana"
  vpc_id      = var.vpc_id

  # SSH Access
  ingress {
    description = "Administrative SSH Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_ingress_cidrs
  }

  # Grafana Dashboard Access
  ingress {
    description = "Grafana Web Interface"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.admin_ingress_cidrs
  }

  # Prometheus Web Interface
  ingress {
    description = "Prometheus Web Interface"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.admin_ingress_cidrs
  }

  # Node Exporter metrics (Internal)
  ingress {
    description = "Node Exporter internal scrape"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.management_subnet_cidr]
  }

  # Outbound rule
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-management-sg"
    Environment = var.environment
  }
}

# 2. Security Group for NFS Storage Server (Node B)
resource "aws_security_group" "storage_server_sg" {
  name        = "${var.project_name}-storage-server-sg"
  description = "Security group for NFS Storage Server"
  vpc_id      = var.vpc_id

  # SSH from Management Subnet or Admin
  ingress {
    description = "SSH from Management Subnet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = concat([var.management_subnet_cidr], var.admin_ingress_cidrs)
  }

  # NFSv4 Traffic (TCP 2049) - Strictly from Storage Subnet & Management Subnet
  ingress {
    description = "NFSv4 Protocol Port"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.storage_subnet_cidr, var.management_subnet_cidr]
  }

  # Node Exporter Scraping - Strictly from Management Subnet
  ingress {
    description = "Node Exporter Metrics Scrape from Prometheus"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.management_subnet_cidr]
  }

  # Outbound rule (HTTPS for S3 backup + package updates)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-storage-server-sg"
    Environment = var.environment
  }
}

# 3. Security Group for NFS Client (Node C)
resource "aws_security_group" "client_sg" {
  name        = "${var.project_name}-client-sg"
  description = "Security group for NFS Client compute node"
  vpc_id      = var.vpc_id

  # SSH Access
  ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = concat([var.management_subnet_cidr], var.admin_ingress_cidrs)
  }

  # Node Exporter Scraping
  ingress {
    description = "Node Exporter Metrics Scrape"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.management_subnet_cidr]
  }

  # Outbound rule (NFS, package updates)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-client-sg"
    Environment = var.environment
  }
}
