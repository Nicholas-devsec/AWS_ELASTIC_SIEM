locals {
  # Assumes the caller provided subnet ids in AZ order [a, b].
  es_masters = {
    a = {
      name       = "es-master-a"
      subnet_id  = var.private_elk_subnet_ids[0]
      az         = var.availability_zones[0]
      private_ip = cidrhost(var.private_elk_subnet_cidrs[0], 10)
    }
    b = {
      name       = "es-master-b"
      subnet_id  = var.private_elk_subnet_ids[1]
      az         = var.availability_zones[1]
      private_ip = cidrhost(var.private_elk_subnet_cidrs[1], 10)
    }
  }

  es_data_nodes = {
    hot1 = {
      name       = "es-data-hot-1"
      subnet_id  = var.private_elk_subnet_ids[0]
      az         = var.availability_zones[0]
      tier       = "hot"
      private_ip = cidrhost(var.private_elk_subnet_cidrs[0], 20)
    }
    hot2 = {
      name       = "es-data-hot-2"
      subnet_id  = var.private_elk_subnet_ids[0]
      az         = var.availability_zones[0]
      tier       = "hot"
      private_ip = cidrhost(var.private_elk_subnet_cidrs[0], 21)
    }
    warm1 = {
      name       = "es-data-warm-1"
      subnet_id  = var.private_elk_subnet_ids[1]
      az         = var.availability_zones[1]
      tier       = "warm"
      private_ip = cidrhost(var.private_elk_subnet_cidrs[1], 20)
    }
    warm2 = {
      name       = "es-data-warm-2"
      subnet_id  = var.private_elk_subnet_ids[1]
      az         = var.availability_zones[1]
      tier       = "warm"
      private_ip = cidrhost(var.private_elk_subnet_cidrs[1], 21)
    }
  }

  logstash_nodes = {
    a = {
      name       = "logstash-a"
      subnet_id  = var.private_ingestion_subnet_ids[0]
      private_ip = cidrhost(var.private_ingestion_subnet_cidrs[0], 10)
    }
    b = {
      name       = "logstash-b"
      subnet_id  = var.private_ingestion_subnet_ids[1]
      private_ip = cidrhost(var.private_ingestion_subnet_cidrs[1], 10)
    }
  }

  kibana_node = {
    name       = "kibana"
    subnet_id  = var.private_elk_subnet_ids[1]
    private_ip = cidrhost(var.private_elk_subnet_cidrs[1], 30)
  }

  initial_master_nodes = ["es-master-a", "es-master-b"]
}

resource "aws_instance" "es_master" {
  for_each = local.es_masters

  ami                    = var.ami_id
  instance_type          = var.es_master_instance_type
  subnet_id              = each.value.subnet_id
  private_ip             = each.value.private_ip
  vpc_security_group_ids = [var.sg_elasticsearch_id]
  iam_instance_profile   = var.es_instance_profile_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size           = var.es_root_volume_gb
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = var.kms_key_arn
  }

  user_data = templatefile("${path.module}/templates/user_data_elasticsearch.sh.tftpl", {
    aws_region                     = var.aws_region
    node_name                      = each.value.name
    is_master                      = true
    is_data                        = false
    az                             = each.value.az
    seed_hosts                     = jsonencode([local.es_masters.a.private_ip, local.es_masters.b.private_ip])
    initial_master_nodes           = jsonencode(local.initial_master_nodes)
    elastic_master_password_secret = var.secret_names.elastic_master_password
    es_tls_secret                  = var.secret_names.tls_elasticsearch_cert
    ca_cert_secret                 = var.secret_names.tls_ca_cert
  })

  tags = merge(var.tags, {
    Name = each.value.name
    role = "elasticsearch-master"
  })
}

resource "aws_instance" "es_data" {
  for_each = local.es_data_nodes

  ami                    = var.ami_id
  instance_type          = var.es_data_instance_type
  subnet_id              = each.value.subnet_id
  private_ip             = each.value.private_ip
  vpc_security_group_ids = [var.sg_elasticsearch_id]
  iam_instance_profile   = var.es_instance_profile_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size           = var.es_root_volume_gb
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = var.kms_key_arn
  }

  ebs_block_device {
    device_name           = "/dev/xvdb"
    volume_size           = var.es_data_volume_gb
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = var.kms_key_arn
  }

  user_data = templatefile("${path.module}/templates/user_data_elasticsearch.sh.tftpl", {
    aws_region                     = var.aws_region
    node_name                      = each.value.name
    is_master                      = false
    is_data                        = true
    az                             = each.value.az
    seed_hosts                     = jsonencode([local.es_masters.a.private_ip, local.es_masters.b.private_ip])
    initial_master_nodes           = jsonencode(local.initial_master_nodes)
    elastic_master_password_secret = var.secret_names.elastic_master_password
    es_tls_secret                  = var.secret_names.tls_elasticsearch_cert
    ca_cert_secret                 = var.secret_names.tls_ca_cert
  })

  tags = merge(var.tags, {
    Name = each.value.name
    role = "elasticsearch-data"
    tier = each.value.tier
  })
}

resource "aws_instance" "logstash" {
  for_each = local.logstash_nodes

  ami                    = var.ami_id
  instance_type          = var.logstash_instance_type
  subnet_id              = each.value.subnet_id
  private_ip             = each.value.private_ip
  vpc_security_group_ids = [var.sg_logstash_id]
  iam_instance_profile   = var.logstash_instance_profile_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size           = var.logstash_root_volume_gb
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = var.kms_key_arn
  }

  user_data = templatefile("${path.module}/templates/user_data_logstash.sh.tftpl", {
    aws_region      = var.aws_region
    es_endpoint     = aws_instance.es_master["a"].private_ip
    es_creds_secret = var.secret_names.logstash_es_credentials
    ca_cert_secret  = var.secret_names.tls_ca_cert
  })

  tags = merge(var.tags, {
    Name = each.value.name
    role = "logstash"
  })
}

resource "aws_instance" "kibana" {
  ami                    = var.ami_id
  instance_type          = var.kibana_instance_type
  subnet_id              = local.kibana_node.subnet_id
  private_ip             = local.kibana_node.private_ip
  vpc_security_group_ids = [var.sg_kibana_id]
  iam_instance_profile   = var.kibana_instance_profile_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size           = var.kibana_root_volume_gb
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = var.kms_key_arn
  }

  user_data = templatefile("${path.module}/templates/user_data_kibana.sh.tftpl", {
    aws_region        = var.aws_region
    es_endpoint       = aws_instance.es_master["a"].private_ip
    es_creds_secret   = var.secret_names.kibana_es_credentials
    ca_cert_secret    = var.secret_names.tls_ca_cert
    kibana_tls_secret = var.secret_names.tls_kibana_cert
  })

  tags = merge(var.tags, {
    Name = local.kibana_node.name
    role = "kibana"
  })
}
