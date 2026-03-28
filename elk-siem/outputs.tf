output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_ingestion_subnet_ids" {
  value = module.vpc.private_ingestion_subnet_ids
}

output "private_elk_subnet_ids" {
  value = module.vpc.private_elk_subnet_ids
}

output "snapshot_bucket_name" {
  value = module.s3.snapshot_bucket_name
}

output "kms_key_arn" {
  value = module.kms.key_arn
}

output "nlb_dns_name" {
  value = module.nlb.dns_name
}

output "kibana_private_ip" {
  value = module.ec2_elk.kibana_private_ip
}

output "elasticsearch_master_private_ips" {
  value = module.ec2_elk.es_master_private_ips
}

output "elasticsearch_data_private_ips" {
  value = module.ec2_elk.es_data_private_ips
}

