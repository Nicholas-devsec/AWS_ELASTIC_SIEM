output "secret_names" {
  value = {
    elastic_master_password       = "siem/elasticsearch/master-password"
    logstash_es_credentials       = "siem/logstash/es-credentials"
    kibana_es_credentials         = "siem/kibana/es-credentials"
    tls_ca_cert                   = "siem/tls/ca-cert"
    tls_logstash_cert             = "siem/tls/logstash-cert"
    tls_kibana_cert               = "siem/tls/kibana-cert"
    tls_es_transport_p12          = "siem/tls/es-transport-p12"
    tls_es_transport_p12_password = "siem/tls/es-transport-p12-password"
  }
}

