data "aws_caller_identity" "current" {}

locals {
  tags = {
    project     = var.project
    environment = var.environment
  }

  account_id = var.account_id != "" ? var.account_id : data.aws_caller_identity.current.account_id

  snapshot_bucket_name = "siem-es-snapshots-${var.environment}-${local.account_id}"
  vpc_flow_bucket_name = "siem-vpc-flow-logs-${var.environment}-${local.account_id}"
  vpc_flow_bucket_arn  = "arn:aws:s3:::${local.vpc_flow_bucket_name}"
}

module "kms" {
  source = "./modules/kms"

  aws_region              = var.aws_region
  environment             = var.environment
  project                 = var.project
  kms_admin_principal_arn = var.kms_admin_principal_arn
  tags                    = local.tags

  log_delivery_s3_bucket_arns = [local.vpc_flow_bucket_arn]
}

module "iam" {
  source = "./modules/iam"

  aws_region           = var.aws_region
  environment          = var.environment
  project              = var.project
  tags                 = local.tags
  kms_key_arn          = module.kms.key_arn
  snapshot_bucket_name = local.snapshot_bucket_name
}

module "secrets" {
  source = "./modules/secrets"

  aws_region  = var.aws_region
  environment = var.environment
  project     = var.project
  tags        = local.tags

  logstash_role_arn      = module.iam.logstash_role_arn
  elasticsearch_role_arn = module.iam.elasticsearch_role_arn
  kibana_role_arn        = module.iam.kibana_role_arn
}

module "vpc" {
  source = "./modules/vpc"

  environment        = var.environment
  project            = var.project
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  tags               = local.tags
}

module "sg" {
  source = "./modules/sg"

  environment        = var.environment
  project            = var.project
  vpc_id             = module.vpc.vpc_id
  beats_source_cidrs = var.beats_source_cidrs
  vpn_cidr_blocks    = var.vpn_cidr_blocks
  tags               = local.tags
}

module "s3" {
  source = "./modules/s3"

  environment            = var.environment
  project                = var.project
  snapshot_bucket_name   = local.snapshot_bucket_name
  kms_key_arn            = module.kms.key_arn
  elasticsearch_role_arn = module.iam.elasticsearch_role_arn
  snapshot_glacier_days  = var.snapshot_glacier_days
  snapshot_delete_days   = var.snapshot_delete_days
  tags                   = local.tags
}

module "ec2_elk" {
  source = "./modules/ec2_elk"

  aws_region  = var.aws_region
  environment = var.environment
  project     = var.project
  tags        = local.tags

  ami_id = var.ami_id

  vpc_id                       = module.vpc.vpc_id
  public_subnet_ids            = module.vpc.public_subnet_ids
  private_elk_subnet_ids       = module.vpc.private_elk_subnet_ids
  private_ingestion_subnet_ids = module.vpc.private_ingestion_subnet_ids

  sg_elasticsearch_id = module.sg.sg_elasticsearch_id
  sg_logstash_id      = module.sg.sg_logstash_id
  sg_kibana_id        = module.sg.sg_kibana_id

  es_instance_profile_name       = module.iam.elasticsearch_instance_profile_name
  logstash_instance_profile_name = module.iam.logstash_instance_profile_name
  kibana_instance_profile_name   = module.iam.kibana_instance_profile_name

  kms_key_arn = module.kms.key_arn

  es_master_instance_type = var.es_master_instance_type
  es_data_instance_type   = var.es_data_instance_type
  logstash_instance_type  = var.logstash_instance_type
  kibana_instance_type    = var.kibana_instance_type

  es_root_volume_gb       = var.es_root_volume_gb
  es_data_volume_gb       = var.es_data_volume_gb
  logstash_root_volume_gb = var.logstash_root_volume_gb
  kibana_root_volume_gb   = var.kibana_root_volume_gb

  secret_names = module.secrets.secret_names

  # Hard requirement: VPC flow logs must exist before any EC2 is launched.
  depends_on = [module.cloudwatch]
}

module "nlb" {
  source = "./modules/nlb"

  environment = var.environment
  project     = var.project
  internal    = var.nlb_internal
  tags        = local.tags

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  sg_nlb_id         = module.sg.sg_nlb_id

  logstash_instance_ids = module.ec2_elk.logstash_instance_ids
}

module "alb" {
  source = "./modules/alb"

  enable_public_kibana = var.enable_public_kibana
  environment          = var.environment
  project              = var.project
  tags                 = local.tags

  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  allowed_analyst_ips = var.allowed_analyst_ips
  acm_cert_arn        = var.acm_cert_arn

  kibana_instance_id = module.ec2_elk.kibana_instance_id
  sg_alb_id          = module.sg.sg_alb_id
}

module "cloudwatch" {
  source = "./modules/cloudwatch"

  aws_region  = var.aws_region
  environment = var.environment
  project     = var.project
  tags        = local.tags

  vpc_id               = module.vpc.vpc_id
  vpc_flow_bucket_name = local.vpc_flow_bucket_name
  kms_key_arn          = module.kms.key_arn
  alert_email          = var.alert_email
}
