output "backend_bucket" {
  value = aws_s3_bucket.state.bucket
}

output "backend_dynamodb_table" {
  value = aws_dynamodb_table.lock.name
}

output "backend_region" {
  value = var.aws_region
}

