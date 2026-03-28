output "dns_name" {
  value = aws_lb.this.dns_name
}

output "nlb_arn_suffix" {
  value = aws_lb.this.arn_suffix
}

output "target_group_arn_suffix" {
  value = aws_lb_target_group.logstash.arn_suffix
}

