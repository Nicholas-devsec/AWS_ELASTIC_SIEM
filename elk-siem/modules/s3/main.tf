resource "aws_s3_bucket" "snapshot" {
  bucket        = var.snapshot_bucket_name
  force_destroy = false

  tags = merge(var.tags, {
    Name = var.snapshot_bucket_name
  })
}

resource "aws_s3_bucket_public_access_block" "snapshot" {
  bucket = aws_s3_bucket.snapshot.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "snapshot" {
  bucket = aws_s3_bucket.snapshot.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "snapshot" {
  bucket = aws_s3_bucket.snapshot.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "snapshot" {
  bucket = aws_s3_bucket.snapshot.id

  rule {
    id     = "snapshot-lifecycle"
    status = "Enabled"

    filter {}

    transition {
      days          = var.snapshot_glacier_days
      storage_class = "GLACIER"
    }

    expiration {
      days = var.snapshot_delete_days
    }
  }
}

data "aws_iam_policy_document" "snapshot_bucket_policy" {
  statement {
    sid       = "AllowElasticsearchRoleBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.snapshot.arn]

    principals {
      type        = "AWS"
      identifiers = [var.elasticsearch_role_arn]
    }
  }

  statement {
    sid       = "AllowElasticsearchRoleObjectRW"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.snapshot.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [var.elasticsearch_role_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "snapshot" {
  bucket = aws_s3_bucket.snapshot.id
  policy = data.aws_iam_policy_document.snapshot_bucket_policy.json

  depends_on = [aws_s3_bucket_public_access_block.snapshot]
}
