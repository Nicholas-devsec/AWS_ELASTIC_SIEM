output "alb_dns_name" {
  value       = try(aws_lb.this[0].dns_name, null)
  description = "ALB DNS name (when enabled)."
}

