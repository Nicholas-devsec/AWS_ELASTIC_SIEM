output "secret_names" {
  value = {
    elastic_master_password = "siem/elasticsearch/master-password"
    logstash_es_credentials = "siem/logstash/es-credentials"
    kibana_es_credentials   = "siem/kibana/es-credentials"
    tls_ca_cert             = "siem/tls/ca-cert"
    tls_logstash_cert       = "siem/tls/logstash-cert"
    tls_kibana_cert         = "siem/tls/kibana-cert"
    tls_elasticsearch_cert  = "siem/tls/elasticsearch-cert"
  }
}
