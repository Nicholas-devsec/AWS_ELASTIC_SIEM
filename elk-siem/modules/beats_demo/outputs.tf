output "instance_id" {
  value = aws_instance.beats_demo.id
}

output "private_ip" {
  value = aws_instance.beats_demo.private_ip
}

output "public_ip" {
  value = aws_instance.beats_demo.public_ip
}

