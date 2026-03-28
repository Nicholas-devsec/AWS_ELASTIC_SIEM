output "elasticsearch_role_arn" {
  value = aws_iam_role.elasticsearch.arn
}

output "logstash_role_arn" {
  value = aws_iam_role.logstash.arn
}

output "kibana_role_arn" {
  value = aws_iam_role.kibana.arn
}

output "elasticsearch_instance_profile_name" {
  value = aws_iam_instance_profile.elasticsearch.name
}

output "logstash_instance_profile_name" {
  value = aws_iam_instance_profile.logstash.name
}

output "kibana_instance_profile_name" {
  value = aws_iam_instance_profile.kibana.name
}

