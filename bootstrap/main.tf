resource "aws_s3_bucket" "state" {
  bucket        = var.state_bucket_name
  force_destroy = false

  tags = {
    Name        = var.state_bucket_name
    project     = var.project
    environment = var.environment
  }
}

resource "aws_kms_key" "tf_state" {
  description             = "Terraform state bucket CMK (${var.project}/${var.environment})"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = {
    Name        = "${var.project}-${var.environment}-tf-state"
    project     = var.project
    environment = var.environment
  }
}

resource "aws_kms_alias" "tf_state" {
  name          = "alias/${var.project}-${var.environment}-tf-state"
  target_key_id = aws_kms_key.tf_state.key_id
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tf_state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_dynamodb_table" "lock" {
  name         = "${var.project}-${var.environment}-${var.lock_table_name}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "${var.project}-${var.environment}-${var.lock_table_name}"
    project     = var.project
    environment = var.environment
  }
}
