output "snapshot_bucket_name" {
  value = aws_s3_bucket.snapshot.bucket
}

output "snapshot_bucket_arn" {
  value = aws_s3_bucket.snapshot.arn
}

