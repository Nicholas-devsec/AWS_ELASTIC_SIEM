output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "public_subnet_cidrs" {
  value = [aws_subnet.public_a.cidr_block, aws_subnet.public_b.cidr_block]
}

output "private_ingestion_subnet_ids" {
  value = [aws_subnet.private_ingestion_a.id, aws_subnet.private_ingestion_b.id]
}

output "private_ingestion_subnet_cidrs" {
  value = [aws_subnet.private_ingestion_a.cidr_block, aws_subnet.private_ingestion_b.cidr_block]
}

output "private_elk_subnet_ids" {
  value = [aws_subnet.private_elk_a.id, aws_subnet.private_elk_b.id]
}

output "private_elk_subnet_cidrs" {
  value = [aws_subnet.private_elk_a.cidr_block, aws_subnet.private_elk_b.cidr_block]
}
