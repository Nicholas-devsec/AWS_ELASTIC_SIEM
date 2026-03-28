output "sg_nlb_id" {
  value = aws_security_group.nlb.id
}

output "sg_logstash_id" {
  value = aws_security_group.logstash.id
}

output "sg_elasticsearch_id" {
  value = aws_security_group.elasticsearch.id
}

output "sg_kibana_id" {
  value = aws_security_group.kibana.id
}

output "sg_alb_id" {
  value = aws_security_group.alb.id
}

