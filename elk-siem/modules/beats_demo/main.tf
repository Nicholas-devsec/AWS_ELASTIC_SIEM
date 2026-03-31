resource "aws_security_group" "beats_demo" {
  name        = "siem-beats-demo-${var.environment}"
  description = "Demo instance running Filebeat to generate sample logs."
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = length(var.admin_cidrs) > 0 ? [1] : []
    content {
      description = "SSH (optional)"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.admin_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "sg_beats_demo"
  })
}

data "aws_iam_policy_document" "assume_ec2" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "beats_demo" {
  name               = "role-siem-beats-demo-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
  tags               = var.tags
}

resource "aws_iam_instance_profile" "beats_demo" {
  name = "ip-siem-beats-demo-${var.environment}"
  role = aws_iam_role.beats_demo.name
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm_beats_demo" {
  role       = aws_iam_role.beats_demo.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_instance" "beats_demo" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.beats_demo.id]
  iam_instance_profile        = aws_iam_instance_profile.beats_demo.name
  associate_public_ip_address = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {

    volume_size           = 16
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = var.kms_key_arn
  }

  user_data = templatefile("${path.module}/templates/user_data_filebeat.sh.tftpl", {
    aws_region    = var.aws_region
    environment   = var.environment
    logstash_host = var.logstash_host
    logstash_port = var.logstash_port
  })

  tags = merge(var.tags, {
    Name = "beats-demo"
    role = "beats-demo"
  })
}
