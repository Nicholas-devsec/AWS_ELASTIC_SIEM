locals {
  az_a = var.availability_zones[0]
  az_b = var.availability_zones[1]

  cidr_public_a            = cidrsubnet(var.vpc_cidr, 8, 1) # 10.0.1.0/24
  cidr_public_b            = cidrsubnet(var.vpc_cidr, 8, 2) # 10.0.2.0/24
  cidr_private_ingestion_a = cidrsubnet(var.vpc_cidr, 8, 3) # 10.0.3.0/24
  cidr_private_ingestion_b = cidrsubnet(var.vpc_cidr, 8, 4) # 10.0.4.0/24
  cidr_private_elk_a       = cidrsubnet(var.vpc_cidr, 8, 5) # 10.0.5.0/24
  cidr_private_elk_b       = cidrsubnet(var.vpc_cidr, 8, 6) # 10.0.6.0/24
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-igw"
  })
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.cidr_public_a
  availability_zone       = local.az_a
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "public-a"
  })
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.cidr_public_b
  availability_zone       = local.az_b
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "public-b"
  })
}

resource "aws_subnet" "private_ingestion_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.cidr_private_ingestion_a
  availability_zone       = local.az_a
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "private-ingestion-a"
  })
}

resource "aws_subnet" "private_ingestion_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.cidr_private_ingestion_b
  availability_zone       = local.az_b
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "private-ingestion-b"
  })
}

resource "aws_subnet" "private_elk_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.cidr_private_elk_a
  availability_zone       = local.az_a
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "private-elk-a"
  })
}

resource "aws_subnet" "private_elk_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.cidr_private_elk_b
  availability_zone       = local.az_b
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "private-elk-b"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-rt-public"
  })
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat_a" {
  domain = "vpc"
  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-eip-nat-a"
  })
}

resource "aws_eip" "nat_b" {
  domain = "vpc"
  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-eip-nat-b"
  })
}

resource "aws_nat_gateway" "a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-nat-a"
  })
}

resource "aws_nat_gateway" "b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.public_b.id

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-nat-b"
  })
}

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.a.id
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-rt-private-a"
  })
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.b.id
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-rt-private-b"
  })
}

resource "aws_route_table_association" "private_ingestion_a" {
  subnet_id      = aws_subnet.private_ingestion_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_elk_a" {
  subnet_id      = aws_subnet.private_elk_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_ingestion_b" {
  subnet_id      = aws_subnet.private_ingestion_b.id
  route_table_id = aws_route_table.private_b.id
}

resource "aws_route_table_association" "private_elk_b" {
  subnet_id      = aws_subnet.private_elk_b.id
  route_table_id = aws_route_table.private_b.id
}

