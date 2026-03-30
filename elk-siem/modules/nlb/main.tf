resource "aws_lb" "this" {
  name               = "siem-beats-${var.environment}"
  internal           = var.internal
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids

  enable_cross_zone_load_balancing = true

  security_groups = [var.sg_nlb_id]

  tags = merge(var.tags, {
    Name = "siem-beats-nlb-${var.environment}"
  })
}

resource "aws_lb_target_group" "logstash" {
  name        = "siem-logstash-${var.environment}"
  port        = 5044
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol = "TCP"
    port     = "5044"
  }

  tags = merge(var.tags, {
    Name = "siem-logstash-tg-${var.environment}"
  })
}

resource "aws_lb_target_group_attachment" "logstash" {
  for_each = var.logstash_instance_ids

  target_group_arn = aws_lb_target_group.logstash.arn
  target_id        = each.value
  port             = 5044
}

resource "aws_lb_listener" "beats" {
  load_balancer_arn = aws_lb.this.arn
  port              = 5044
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.logstash.arn
  }
}
