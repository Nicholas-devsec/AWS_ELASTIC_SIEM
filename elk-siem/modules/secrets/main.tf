locals {
  secret_names = [
    "siem/elasticsearch/master-password",
    "siem/logstash/es-credentials",
    "siem/kibana/es-credentials",
    "siem/tls/ca-cert",
    "siem/tls/logstash-cert",
    "siem/tls/kibana-cert",
    "siem/tls/es-transport-p12",
    "siem/tls/es-transport-p12-password"
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

  name = each.value

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

