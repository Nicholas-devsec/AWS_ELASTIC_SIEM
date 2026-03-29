data "aws_caller_identity" "current" {}

locals {
  snapshot_bucket_arn = "arn:aws:s3:::${var.snapshot_bucket_name}"
  account_id          = var.account_id != "" ? var.account_id : data.aws_caller_identity.current.account_id
}

data "aws_iam_policy_document" "assume_ec2" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "elasticsearch" {
  name               = "role-siem-elasticsearch-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
  tags               = var.tags
}

resource "aws_iam_role" "logstash" {
  name               = "role-siem-logstash-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
  tags               = var.tags
}

resource "aws_iam_role" "kibana" {
  name               = "role-siem-kibana-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
  tags               = var.tags
}

resource "aws_iam_instance_profile" "elasticsearch" {
  name = "ip-siem-elasticsearch-${var.environment}"
  role = aws_iam_role.elasticsearch.name
  tags = var.tags
}

resource "aws_iam_instance_profile" "logstash" {
  name = "ip-siem-logstash-${var.environment}"
  role = aws_iam_role.logstash.name
  tags = var.tags
}

resource "aws_iam_instance_profile" "kibana" {
  name = "ip-siem-kibana-${var.environment}"
  role = aws_iam_role.kibana.name
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm_elasticsearch" {
  role       = aws_iam_role.elasticsearch.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm_logstash" {
  role       = aws_iam_role.logstash.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm_kibana" {
  role       = aws_iam_role.kibana.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cw_agent_elasticsearch" {
  role       = aws_iam_role.elasticsearch.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "cw_agent_logstash" {
  role       = aws_iam_role.logstash.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "cw_agent_kibana" {
  role       = aws_iam_role.kibana.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

data "aws_iam_policy_document" "logstash_inline" {
  statement {
    sid     = "ReadLogstashSecrets"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:siem/logstash/*",
      "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:siem/tls/*"
    ]
  }
}

resource "aws_iam_role_policy" "logstash_inline" {
  name   = "siem-logstash-inline-${var.environment}"
  role   = aws_iam_role.logstash.id
  policy = data.aws_iam_policy_document.logstash_inline.json
}

data "aws_iam_policy_document" "kibana_inline" {
  statement {
    sid     = "ReadKibanaSecrets"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:siem/kibana/*",
      "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:siem/tls/*"
    ]
  }

  statement {
    sid       = "PutCustomMetrics"
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "kibana_inline" {
  name   = "siem-kibana-inline-${var.environment}"
  role   = aws_iam_role.kibana.id
  policy = data.aws_iam_policy_document.kibana_inline.json
}

data "aws_iam_policy_document" "elasticsearch_inline" {
  statement {
    sid     = "ReadElasticsearchSecrets"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:siem/elasticsearch/*",
      "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:siem/tls/*"
    ]
  }

  statement {
    sid     = "SnapshotBucketAccess"
    effect  = "Allow"
    actions = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
    resources = [
      local.snapshot_bucket_arn,
      "${local.snapshot_bucket_arn}/*"
    ]
  }

  statement {
    sid       = "UseKmsForSnapshots"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"]
    resources = [var.kms_key_arn]
  }

  statement {
    sid       = "PutCustomMetrics"
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "elasticsearch_inline" {
  name   = "siem-elasticsearch-inline-${var.environment}"
  role   = aws_iam_role.elasticsearch.id
  policy = data.aws_iam_policy_document.elasticsearch_inline.json
}
