locals {
  secret_names = [
    "siem/elasticsearch/master-password",
    "siem/logstash/es-credentials",
    "siem/kibana/es-credentials",
    "siem/tls/ca-cert",
    "siem/tls/logstash-cert",
    "siem/tls/kibana-cert",
    "siem/tls/elasticsearch-cert"
  ]

  readers_by_prefix = {
    "siem/elasticsearch/" = [var.elasticsearch_role_arn]
    "siem/logstash/"      = [var.logstash_role_arn]
    "siem/kibana/"        = [var.kibana_role_arn]
    "siem/tls/"           = [var.elasticsearch_role_arn, var.logstash_role_arn, var.kibana_role_arn]
  }
}

resource "aws_secretsmanager_secret" "this" {
  for_each = toset(local.secret_names)

  name                    = each.value
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(var.tags, {
    Name = each.value
  })
}

data "aws_iam_policy_document" "secret_policy" {
  for_each = aws_secretsmanager_secret.this

  statement {
    sid     = "AllowReadOnlyToInstanceRoles"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]

    principals {
      type = "AWS"
      identifiers = distinct(flatten([
        for prefix, readers in local.readers_by_prefix :
        startswith(each.key, prefix) ? readers : []
      ]))
    }

    resources = [each.value.arn]
  }
}

resource "aws_secretsmanager_secret_policy" "this" {
  for_each = aws_secretsmanager_secret.this

  secret_arn = each.value.arn
  policy     = data.aws_iam_policy_document.secret_policy[each.key].json
}

resource "random_password" "elastic_master" {
  length           = 32
  special          = true
  override_special = "_%@-"
}

resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "siem-ca"
    organization = var.project
  }

  is_ca_certificate     = true
  validity_period_hours = 87600 # ~10 years

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
    "key_encipherment"
  ]
}

resource "tls_private_key" "logstash" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "logstash" {
  private_key_pem = tls_private_key.logstash.private_key_pem

  subject {
    common_name  = "logstash"
    organization = var.project
  }
}

resource "tls_locally_signed_cert" "logstash" {
  cert_request_pem      = tls_cert_request.logstash.cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = 8760 # ~1 year

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}

resource "tls_private_key" "kibana" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "kibana" {
  private_key_pem = tls_private_key.kibana.private_key_pem

  subject {
    common_name  = "kibana"
    organization = var.project
  }
}

resource "tls_locally_signed_cert" "kibana" {
  cert_request_pem      = tls_cert_request.kibana.cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = 8760 # ~1 year

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}

resource "tls_private_key" "elasticsearch" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "elasticsearch" {
  private_key_pem = tls_private_key.elasticsearch.private_key_pem

  subject {
    common_name  = "elasticsearch"
    organization = var.project
  }

  dns_names    = ["localhost"]
  ip_addresses = ["127.0.0.1"]
}

resource "tls_locally_signed_cert" "elasticsearch" {
  cert_request_pem      = tls_cert_request.elasticsearch.cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = 8760 # ~1 year

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}

resource "aws_secretsmanager_secret_version" "elastic_master_password" {
  secret_id     = aws_secretsmanager_secret.this["siem/elasticsearch/master-password"].id
  secret_string = random_password.elastic_master.result

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_version" "logstash_es_credentials" {
  secret_id = aws_secretsmanager_secret.this["siem/logstash/es-credentials"].id
  secret_string = jsonencode({
    user     = "elastic"
    password = random_password.elastic_master.result
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_version" "kibana_es_credentials" {
  secret_id = aws_secretsmanager_secret.this["siem/kibana/es-credentials"].id
  secret_string = jsonencode({
    user     = "kibana_system"
    password = random_password.elastic_master.result
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_version" "tls_ca_cert" {
  secret_id     = aws_secretsmanager_secret.this["siem/tls/ca-cert"].id
  secret_string = tls_self_signed_cert.ca.cert_pem

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_version" "tls_logstash_cert" {
  secret_id = aws_secretsmanager_secret.this["siem/tls/logstash-cert"].id
  secret_string = jsonencode({
    crt = tls_locally_signed_cert.logstash.cert_pem
    key = tls_private_key.logstash.private_key_pem
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_version" "tls_kibana_cert" {
  secret_id = aws_secretsmanager_secret.this["siem/tls/kibana-cert"].id
  secret_string = jsonencode({
    crt = tls_locally_signed_cert.kibana.cert_pem
    key = tls_private_key.kibana.private_key_pem
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_version" "tls_elasticsearch_cert" {
  secret_id = aws_secretsmanager_secret.this["siem/tls/elasticsearch-cert"].id
  secret_string = jsonencode({
    crt = tls_locally_signed_cert.elasticsearch.cert_pem
    key = tls_private_key.elasticsearch.private_key_pem
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
