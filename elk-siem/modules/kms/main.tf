data "aws_caller_identity" "current" {}

locals {
  account_id = var.account_id != "" ? var.account_id : data.aws_caller_identity.current.account_id
}

data "aws_iam_policy_document" "key_policy" {
  statement {
    sid     = "EnableAccountRootPermissions"
    effect  = "Allow"
    actions = ["kms:*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }

    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.kms_admin_principal_arn != "" ? [1] : []
    content {
      sid     = "AllowDedicatedKeyAdmin"
      effect  = "Allow"
      actions = ["kms:*"]

      principals {
        type        = "AWS"
        identifiers = [var.kms_admin_principal_arn]
      }

      resources = ["*"]
    }
  }

  # Delegate key usage authorization to IAM policies within this account.
  statement {
    sid    = "AllowIAMDelegationInAccount"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant"
    ]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalAccount"
      values   = [local.account_id]
    }
  }

  dynamic "statement" {
    for_each = length(var.log_delivery_s3_bucket_arns) > 0 ? [1] : []
    content {
      sid    = "AllowAWSLogDeliveryForS3"
      effect = "Allow"

      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]

      principals {
        type        = "Service"
        identifiers = ["delivery.logs.amazonaws.com"]
      }

      resources = ["*"]

      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["s3.${var.aws_region}.amazonaws.com"]
      }

      condition {
        test     = "StringLike"
        variable = "kms:EncryptionContext:aws:s3:arn"
        values   = flatten([for b in var.log_delivery_s3_bucket_arns : ["${b}/*", b]])
      }
    }
  }
}

resource "aws_kms_key" "siem" {
  description             = "ELK SIEM KMS key (${var.environment})"
  enable_key_rotation     = true
  deletion_window_in_days = var.deletion_window_in_days
  policy                  = data.aws_iam_policy_document.key_policy.json

  tags = merge(var.tags, {
    Name = "siem-kms-${var.environment}"
  })
}

resource "aws_kms_alias" "siem" {
  name          = "alias/siem-${var.environment}"
  target_key_id = aws_kms_key.siem.key_id
}
