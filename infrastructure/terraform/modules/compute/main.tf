# Official Canonical Ubuntu Server 24.04 LTS AMI Lookup
data "aws_ami" "ubuntu_24_04" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 1. Management & Monitoring Node (Ansible Control, Prometheus, Grafana, Alertmanager)
resource "aws_instance" "management" {
  ami                  = data.aws_ami.ubuntu_24_04.id
  instance_type        = var.management_instance_type
  key_name             = var.ssh_key_name
  subnet_id            = var.management_subnet_id
  vpc_security_group_ids = [var.management_sg_id]
  iam_instance_profile = var.instance_profile_name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    tags = {
      Name = "${var.project_name}-management-root"
    }
  }

  tags = {
    Name        = "${var.project_name}-management-node"
    Environment = var.environment
    Role        = "Management-Monitoring"
  }
}

# 2. NFS Storage Server (LVM, XFS, NFSv4 Server, S3 Backup Engine)
resource "aws_instance" "storage_server" {
  ami                  = data.aws_ami.ubuntu_24_04.id
  instance_type        = var.storage_instance_type
  key_name             = var.ssh_key_name
  subnet_id            = var.storage_subnet_id
  vpc_security_group_ids = [var.storage_server_sg_id]
  iam_instance_profile = var.instance_profile_name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    tags = {
      Name = "${var.project_name}-storage-root"
    }
  }

  tags = {
    Name        = "${var.project_name}-nfs-storage-server"
    Environment = var.environment
    Role        = "NFS-Storage-Server"
  }
}

# Attach Dedicated EBS Volume to Storage Server for LVM Pool
resource "aws_volume_attachment" "nfs_storage_attach" {
  device_name = "/dev/sdb"
  volume_id   = var.nfs_ebs_volume_id
  instance_id = aws_instance.storage_server.id
}

# 3. NFS Client (Compute Node, Persistent Mount /mnt/nfs_share)
resource "aws_instance" "client" {
  ami                  = data.aws_ami.ubuntu_24_04.id
  instance_type        = var.client_instance_type
  key_name             = var.ssh_key_name
  subnet_id            = var.storage_subnet_id
  vpc_security_group_ids = [var.client_sg_id]
  iam_instance_profile = var.instance_profile_name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    tags = {
      Name = "${var.project_name}-client-root"
    }
  }

  tags = {
    Name        = "${var.project_name}-nfs-client"
    Environment = var.environment
    Role        = "NFS-Client"
  }
}
