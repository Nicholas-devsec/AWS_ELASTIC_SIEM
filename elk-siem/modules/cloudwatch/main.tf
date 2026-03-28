resource "aws_cloudwatch_log_group" "vpc_flow" {
  name              = "/siem/vpc-flow-logs"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "logstash" {
  name              = "/siem/logstash"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "elasticsearch" {
  name              = "/siem/elasticsearch"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "kibana" {
  name              = "/siem/kibana"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_s3_bucket" "vpc_flow" {
  bucket        = var.vpc_flow_bucket_name
  force_destroy = false

  tags = merge(var.tags, {
    Name = var.vpc_flow_bucket_name
  })
}

resource "aws_s3_bucket_public_access_block" "vpc_flow" {
  bucket = aws_s3_bucket.vpc_flow.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "vpc_flow" {
  bucket = aws_s3_bucket.vpc_flow.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "vpc_flow" {
  bucket = aws_s3_bucket.vpc_flow.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

data "aws_iam_policy_document" "vpc_flow_bucket_policy" {
  statement {
    sid     = "AWSLogDeliveryWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    resources = ["${aws_s3_bucket.vpc_flow.arn}/AWSLogs/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid     = "AWSLogDeliveryCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl", "s3:ListBucket"]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    resources = [aws_s3_bucket.vpc_flow.arn]
  }
}

resource "aws_s3_bucket_policy" "vpc_flow" {
  bucket = aws_s3_bucket.vpc_flow.id
  policy = data.aws_iam_policy_document.vpc_flow_bucket_policy.json

  depends_on = [aws_s3_bucket_public_access_block.vpc_flow]
}

data "aws_iam_policy_document" "flow_logs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_logs_to_cw" {
  name               = "role-siem-vpc-flow-logs-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "flow_logs_to_cw" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = ["${aws_cloudwatch_log_group.vpc_flow.arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow_logs_to_cw" {
  name   = "siem-vpc-flow-logs-to-cw-${var.environment}"
  role   = aws_iam_role.flow_logs_to_cw.id
  policy = data.aws_iam_policy_document.flow_logs_to_cw.json
}

resource "aws_flow_log" "to_cloudwatch" {
  vpc_id               = var.vpc_id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow.arn
  iam_role_arn         = aws_iam_role.flow_logs_to_cw.arn

  tags = merge(var.tags, {
    Name = "siem-vpc-flow-to-cw-${var.environment}"
  })
}

resource "aws_flow_log" "to_s3" {
  vpc_id               = var.vpc_id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = aws_s3_bucket.vpc_flow.arn

  tags = merge(var.tags, {
    Name = "siem-vpc-flow-to-s3-${var.environment}"
  })
}

resource "aws_sns_topic" "alerts" {
  name = "siem-alerts-${var.environment}"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "es_cluster_health_red" {
  alarm_name          = "siem-es-cluster-health-red-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 5
  metric_name         = "ClusterHealth"
  namespace           = "SIEM/Elasticsearch"
  period              = 60
  statistic           = "Maximum"
  threshold           = 2
  alarm_actions       = [aws_sns_topic.alerts.arn]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "logstash_queue_depth" {
  alarm_name          = "siem-logstash-queue-depth-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "QueueDepth"
  namespace           = "SIEM/Logstash"
  period              = 60
  statistic           = "Maximum"
  threshold           = 10000
  alarm_actions       = [aws_sns_topic.alerts.arn]

  tags = var.tags
}
