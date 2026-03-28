output "flow_logs_id" {
  value = aws_flow_log.to_cloudwatch.id
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

