# 1. Networking Module (VPC, Subnets, Gateways, Route Tables)
module "networking" {
  source = "../../modules/networking"

  project_name                = var.project_name
  environment                 = var.environment
  vpc_cidr                    = var.vpc_cidr
  management_subnet_cidr      = var.management_subnet_cidr
  storage_subnet_cidr         = var.storage_subnet_cidr
  availability_zone           = var.availability_zone
  assign_public_ip_to_storage = var.assign_public_ip_to_storage
}

# 2. Security Module (Security Groups for Management, Storage, and Client)
module "security" {
  source = "../../modules/security"

  project_name           = var.project_name
  environment            = var.environment
  vpc_id                 = module.networking.vpc_id
  admin_ingress_cidrs    = var.admin_ingress_cidrs
  management_subnet_cidr = module.networking.management_subnet_cidr
  storage_subnet_cidr    = module.networking.storage_subnet_cidr
}

# 3. Storage Module (Dedicated EBS Volume & S3 Disaster Recovery Bucket)
module "storage" {
  source = "../../modules/storage"

  project_name                      = var.project_name
  environment                       = var.environment
  availability_zone                 = var.availability_zone
  ebs_volume_size                   = var.ebs_volume_size
  backup_retention_days             = var.backup_retention_days
  noncurrent_version_retention_days = var.noncurrent_version_retention_days
}

# 4. IAM Module (EC2 Instance Profile, SSM Core, Scoped S3 DR Policy)
module "iam" {
  source = "../../modules/iam"

  project_name  = var.project_name
  environment   = var.environment
  s3_bucket_arn = module.storage.s3_bucket_arn
}

# 5. Compute Module (EC2 Instances: Management, Storage Server, and Client)
module "compute" {
  source = "../../modules/compute"

  project_name             = var.project_name
  environment              = var.environment
  ssh_key_name             = var.ssh_key_name
  management_instance_type = var.management_instance_type
  storage_instance_type    = var.storage_instance_type
  client_instance_type     = var.client_instance_type
  management_subnet_id     = module.networking.management_subnet_id
  storage_subnet_id        = module.networking.storage_subnet_id
  management_sg_id         = module.security.management_sg_id
  storage_server_sg_id     = module.security.storage_server_sg_id
  client_sg_id             = module.security.client_sg_id
  management_instance_profile_name     = module.iam.management_instance_profile_name
  storage_server_instance_profile_name = module.iam.storage_server_instance_profile_name
  client_instance_profile_name         = module.iam.client_instance_profile_name
  nfs_ebs_volume_id        = module.storage.ebs_volume_id
}
