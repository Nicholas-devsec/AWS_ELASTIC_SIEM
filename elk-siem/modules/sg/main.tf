resource "aws_security_group" "nlb" {
  name        = "sg-nlb-${var.environment}"
  description = "NLB security group (Beats ingest)."
  vpc_id      = var.vpc_id

  ingress {
    description = "Beats ingest"
    from_port   = 5044
    to_port     = 5044
    protocol    = "tcp"
    cidr_blocks = var.beats_source_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "sg_nlb"
  })
}

resource "aws_security_group" "logstash" {
  name        = "sg-logstash-${var.environment}"
  description = "Logstash nodes."
  vpc_id      = var.vpc_id

  ingress {
    description     = "From NLB"
    from_port       = 5044
    to_port         = 5044
    protocol        = "tcp"
    security_groups = [aws_security_group.nlb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "sg_logstash"
  })
}

resource "aws_security_group" "alb" {
  name        = "sg-alb-${var.environment}"
  description = "Reserved for future public Kibana ALB."
  vpc_id      = var.vpc_id

  # Intentionally no ingress by default; when enable_public_kibana=true the ALB module should
  # add rules or you should update this SG with an allowlist on 443.

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "sg_alb"
  })
}

resource "aws_security_group" "kibana" {
  name        = "sg-kibana-${var.environment}"
  description = "Kibana (private access)."
  vpc_id      = var.vpc_id

  ingress {
    description = "Kibana access from VPN"
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = var.vpn_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "sg_kibana"
  })
}

resource "aws_security_group" "elasticsearch" {
  name        = "sg-elasticsearch-${var.environment}"
  description = "Elasticsearch cluster nodes."
  vpc_id      = var.vpc_id

  ingress {
    description     = "ES HTTP from Logstash"
    from_port       = 9200
    to_port         = 9200
    protocol        = "tcp"
    security_groups = [aws_security_group.logstash.id]
  }

  ingress {
    description     = "ES transport from Logstash (rare; for completeness)"
    from_port       = 9300
    to_port         = 9300
    protocol        = "tcp"
    security_groups = [aws_security_group.logstash.id]
  }

  ingress {
    description     = "ES HTTP from Kibana"
    from_port       = 9200
    to_port         = 9200
    protocol        = "tcp"
    security_groups = [aws_security_group.kibana.id]
  }

  ingress {
    description = "ES transport within cluster"
    from_port   = 9300
    to_port     = 9300
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "sg_elasticsearch"
  })
}

