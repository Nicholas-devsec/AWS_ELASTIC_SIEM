data "aws_subnet" "private_elk" {
  for_each = toset(var.private_elk_subnet_ids)
  id       = each.value
}

data "aws_subnet" "private_ingestion" {
  for_each = toset(var.private_ingestion_subnet_ids)
  id       = each.value
}

locals {
  # Assumes the caller provided subnet ids in AZ order [a, b].
  es_masters = {
    a = {
      name      = "es-master-a"
      subnet_id = var.private_elk_subnet_ids[0]
      az        = data.aws_subnet.private_elk[var.private_elk_subnet_ids[0]].availability_zone
    }
    b = {
      name      = "es-master-b"
      subnet_id = var.private_elk_subnet_ids[1]
      az        = data.aws_subnet.private_elk[var.private_elk_subnet_ids[1]].availability_zone
    }
  }

  es_data_nodes = {
    hot1 = {
      name      = "es-data-hot-1"
      subnet_id = var.private_elk_subnet_ids[0]
      az        = data.aws_subnet.private_elk[var.private_elk_subnet_ids[0]].availability_zone
      tier      = "hot"
    }
    hot2 = {
      name      = "es-data-hot-2"
      subnet_id = var.private_elk_subnet_ids[0]
      az        = data.aws_subnet.private_elk[var.private_elk_subnet_ids[0]].availability_zone
      tier      = "hot"
    }
    warm1 = {
      name      = "es-data-warm-1"
      subnet_id = var.private_elk_subnet_ids[1]
      az        = data.aws_subnet.private_elk[var.private_elk_subnet_ids[1]].availability_zone
      tier      = "warm"
    }
    warm2 = {
      name      = "es-data-warm-2"
      subnet_id = var.private_elk_subnet_ids[1]
      az        = data.aws_subnet.private_elk[var.private_elk_subnet_ids[1]].availability_zone
      tier      = "warm"
    }
  }

  logstash_nodes = {
    a = {
      name      = "logstash-a"
      subnet_id = var.private_ingestion_subnet_ids[0]
    }
    b = {
      name      = "logstash-b"
      subnet_id = var.private_ingestion_subnet_ids[1]
    }
  }

  kibana_node = {
    name      = "kibana"
    subnet_id = var.private_elk_subnet_ids[1]
  }

  initial_master_nodes = ["es-master-a", "es-master-b"]
}

resource "aws_instance" "es_master" {
  for_each = local.es_masters

  ami                    = var.ami_id
  instance_type          = var.es_master_instance_type
  subnet_id              = each.value.subnet_id
  vpc_security_group_ids = [var.sg_elasticsearch_id]
  iam_instance_profile   = var.es_instance_profile_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = var.es_root_volume_gb
    volume_type = "gp3"
    encrypted   = true
    kms_key_id  = var.kms_key_arn
  }

  user_data = templatefile("${path.module}/templates/user_data_elasticsearch.sh.tftpl", {
    aws_region                       = var.aws_region
    node_name                        = each.value.name
    is_master                        = true
    is_data                          = false
    az                               = each.value.az
    seed_hosts                       = jsonencode([for _, inst in aws_instance.es_master : inst.private_ip])
    initial_master_nodes             = jsonencode(local.initial_master_nodes)
    elastic_master_password_secret   = var.secret_names.elastic_master_password
    es_transport_p12_secret          = var.secret_names.tls_es_transport_p12
    es_transport_p12_password_secret = var.secret_names.tls_es_transport_p12_password
    ca_cert_secret                   = var.secret_names.tls_ca_cert
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
  vpc_security_group_ids = [var.sg_elasticsearch_id]
  iam_instance_profile   = var.es_instance_profile_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = var.es_root_volume_gb
    volume_type = "gp3"
    encrypted   = true
    kms_key_id  = var.kms_key_arn
  }

  ebs_block_device {
    device_name = "/dev/xvdb"
    volume_size = var.es_data_volume_gb
    volume_type = "gp3"
    encrypted   = true
    kms_key_id  = var.kms_key_arn
  }

  user_data = templatefile("${path.module}/templates/user_data_elasticsearch.sh.tftpl", {
    aws_region                       = var.aws_region
    node_name                        = each.value.name
    is_master                        = false
    is_data                          = true
    az                               = each.value.az
    seed_hosts                       = jsonencode([for _, inst in aws_instance.es_master : inst.private_ip])
    initial_master_nodes             = jsonencode(local.initial_master_nodes)
    elastic_master_password_secret   = var.secret_names.elastic_master_password
    es_transport_p12_secret          = var.secret_names.tls_es_transport_p12
    es_transport_p12_password_secret = var.secret_names.tls_es_transport_p12_password
    ca_cert_secret                   = var.secret_names.tls_ca_cert
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
  vpc_security_group_ids = [var.sg_logstash_id]
  iam_instance_profile   = var.logstash_instance_profile_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = var.logstash_root_volume_gb
    volume_type = "gp3"
    encrypted   = true
    kms_key_id  = var.kms_key_arn
  }

  user_data = templatefile("${path.module}/templates/user_data_logstash.sh.tftpl", {
    aws_region          = var.aws_region
    es_endpoint         = aws_instance.es_master["a"].private_ip
    es_creds_secret     = var.secret_names.logstash_es_credentials
    ca_cert_secret      = var.secret_names.tls_ca_cert
    logstash_tls_secret = var.secret_names.tls_logstash_cert
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
  vpc_security_group_ids = [var.sg_kibana_id]
  iam_instance_profile   = var.kibana_instance_profile_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = var.kibana_root_volume_gb
    volume_type = "gp3"
    encrypted   = true
    kms_key_id  = var.kms_key_arn
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
