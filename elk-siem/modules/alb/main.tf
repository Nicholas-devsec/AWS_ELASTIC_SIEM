locals {
  enabled = var.enable_public_kibana ? 1 : 0
}

resource "aws_security_group_rule" "allow_https" {
  count             = local.enabled
  type              = "ingress"
  security_group_id = var.sg_alb_id
  description       = "Allow analyst IPs to reach Kibana ALB"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_analyst_ips
}

resource "aws_lb" "this" {
  count              = local.enabled
  name               = "siem-kibana-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.sg_alb_id]
  subnets            = var.public_subnet_ids

  tags = merge(var.tags, {
    Name = "siem-kibana-alb-${var.environment}"
  })
}

resource "aws_lb_target_group" "kibana" {
  count    = local.enabled
  name     = "siem-kibana-${var.environment}"
  port     = 5601
  protocol = "HTTPS"
  vpc_id   = var.vpc_id

  health_check {
    protocol = "HTTPS"
    path     = "/api/status"
    port     = "5601"
  }

  tags = merge(var.tags, {
    Name = "siem-kibana-tg-${var.environment}"
  })
}

resource "aws_lb_target_group_attachment" "kibana" {
  count            = local.enabled
  target_group_arn = aws_lb_target_group.kibana[0].arn
  target_id        = var.kibana_instance_id
  port             = 5601
}

resource "aws_lb_listener" "http" {
  count             = local.enabled
  load_balancer_arn = aws_lb.this[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = local.enabled
  load_balancer_arn = aws_lb.this[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_cert_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kibana[0].arn
  }
}

resource "aws_wafv2_ip_set" "allowlist" {
  count              = local.enabled
  name               = "siem-kibana-allow-${var.environment}"
  description        = "Allowed analyst IPs for Kibana"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.allowed_analyst_ips
}

resource "aws_wafv2_web_acl" "this" {
  count       = local.enabled
  name        = "siem-kibana-waf-${var.environment}"
  description = "Kibana allowlist WebACL"
  scope       = "REGIONAL"

  default_action {
    block {}
  }

  rule {
    name     = "AllowAnalystIPs"
    priority = 1

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.allowlist[0].arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowAnalystIPs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "siemKibanaWebACL"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

resource "aws_wafv2_web_acl_association" "this" {
  count        = local.enabled
  resource_arn = aws_lb.this[0].arn
  web_acl_arn  = aws_wafv2_web_acl.this[0].arn
}
