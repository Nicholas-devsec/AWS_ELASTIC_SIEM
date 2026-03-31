# AWS ELK SIEM (Terraform)

This folder contains the Terraform implementation for the Elastic SIEM lab.

Key defaults in this implementation:
- Kibana is private-only (VPN/SSM); `enable_public_kibana = false` by default.
- TLS terminates on instances (no ACM in Terraform for v1).
- Secrets Manager **secret containers only** are created by Terraform; populate secret values out-of-band before EC2 boot.

Recommended workflow:
1) Create remote-state infra via `../bootstrap`.
2) Paste the `backend "s3"` config into `versions.tf`.
3) `terraform init`, then apply in phases (foundation → core → observability).

Secret payload expectations (populate via AWS Console/CLI):
- `siem/elasticsearch/master-password`: plaintext password string for `elastic` user.
- `siem/logstash/es-credentials`: JSON: `{"user":"logstash_internal","password":"..."}`
- `siem/kibana/es-credentials`: JSON: `{"user":"kibana_system","password":"..."}`
- `siem/tls/ca-cert`: PEM string for CA cert.
- `siem/tls/logstash-cert`: JSON: `{"crt":"PEM","key":"PEM"}`
- `siem/tls/kibana-cert`: JSON: `{"crt":"PEM","key":"PEM"}`
- `siem/tls/es-transport-p12`: base64-encoded PKCS12 content.
- `siem/tls/es-transport-p12-password` (optional): plaintext password string (empty if none).
