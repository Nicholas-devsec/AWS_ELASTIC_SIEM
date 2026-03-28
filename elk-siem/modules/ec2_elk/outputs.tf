output "logstash_instance_ids" {
  value = [for _, inst in aws_instance.logstash : inst.id]
}

output "kibana_instance_id" {
  value = aws_instance.kibana.id
}

output "kibana_private_ip" {
  value = aws_instance.kibana.private_ip
}

output "es_master_private_ips" {
  value = { for k, inst in aws_instance.es_master : k => inst.private_ip }
}

output "es_master_instance_ids" {
  value = { for k, inst in aws_instance.es_master : k => inst.id }
}

output "es_data_private_ips" {
  value = { for k, inst in aws_instance.es_data : k => inst.private_ip }
}

output "instance_ids_for_dependency" {
  value = {
    masters  = [for _, inst in aws_instance.es_master : inst.id]
    data     = [for _, inst in aws_instance.es_data : inst.id]
    logstash = [for _, inst in aws_instance.logstash : inst.id]
    kibana   = [aws_instance.kibana.id]
  }
}
