# AWS ELK SIEM — Terraform Architecture Plan

> Scope: Small-scale ELK SIEM (1–50 log sources) on EC2, multi-AZ, us-west-2.
> Stack: Elasticsearch + Logstash + Kibana, provisioned entirely via Terraform.

---

## 1. Terraform Module Structure

Implement modules in this dependency order — do not deviate.

```
elk-siem/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
└── modules/
    ├── kms/           # 1 — CMK for EBS + S3 encryption
    ├── iam/           # 2 — instance profiles, least-priv policies
    ├── secrets/       # 3 — Secrets Manager: ES creds, TLS certs
    ├── vpc/           # 4 — VPC, subnets, IGW, NAT GW, route tables
    ├── sg/            # 5 — all security groups
    ├── s3/            # 6 — ES snapshot bucket
    ├── ec2_elk/       # 7 — ES master nodes, data nodes, Logstash, Kibana
    ├── nlb/           # 8 — NLB for Beats ingest (port 5044)
    ├── alb/           # 9 — ALB + WAF for Kibana HTTPS
    └── cloudwatch/    # 10 — log groups, alarms, VPC flow log delivery
```

---

## 2. Network Architecture

### VPC layout

| Subnet | CIDR | AZ | Purpose |
|--------|------|----|---------|
| public-a | 10.0.1.0/24 | us-west-2a | Bastion, NLB, ALB |
| public-b | 10.0.2.0/24 | us-west-2b | Bastion, NLB, ALB |
| private-ingestion-a | 10.0.3.0/24 | us-west-2a | Logstash |
| private-ingestion-b | 10.0.4.0/24 | us-west-2b | Logstash |
| private-elk-a | 10.0.5.0/24 | us-west-2a | ES master + data nodes |
| private-elk-b | 10.0.6.0/24 | us-west-2b | ES data nodes, Kibana |

- Public subnets route 0.0.0.0/0 to Internet Gateway
- Private subnets route 0.0.0.0/0 to their AZ-local NAT Gateway (one NAT GW per AZ)
- VPC flow logs enabled, ALL traffic, delivered to CloudWatch log group and S3

### Security groups — allowed ingress only

| SG name | Source | Port | Protocol |
|---------|--------|------|----------|
| sg_bastion | var.trusted_cidr_blocks | 22 | TCP |
| sg_nlb | var.beats_source_cidrs | 5044 | TCP |
| sg_logstash | sg_nlb | 5044 | TCP |
| sg_elasticsearch | sg_logstash, sg_kibana | 9200, 9300 | TCP |
| sg_kibana | sg_alb | 5601 | TCP |
| sg_alb | var.allowed_analyst_ips | 443 | TCP |

All egress is open. No 0.0.0.0/0 ingress on any SG except sg_alb port 443.

---

## 3. EC2 Instances

### Elasticsearch cluster

| Role | Count | Instance type | AZ placement |
|------|-------|---------------|--------------|
| Master node | 2 | r5.large | one per AZ |
| Data node — hot tier | 2 | r5.xlarge | us-west-2a |
| Data node — warm tier | 2 | r5.xlarge | us-west-2b |

Master nodes are dedicated — `node.master: true`, `node.data: false`.
Data nodes are data-only — `node.master: false`, `node.data: true`.

### Logstash

| Count | Instance type | AZ placement |
|-------|---------------|--------------|
| 2 | c5.large | one per AZ |

Both instances registered in the NLB target group on port 5044.

### Kibana

| Count | Instance type | Subnet |
|-------|---------------|--------|
| 1 | t3.large | private-elk-b |

Sits behind the ALB. Can add a second instance in private-elk-a later for HA.

---

## 4. Configuration Templates

### elasticsearch.yml (via Terraform templatefile)

```yaml
cluster.name: elk-siem
node.name: ${node_name}
node.master: ${is_master}
node.data: ${is_data}
node.attr.aws_availability_zone: ${az}

network.host: 0.0.0.0
discovery.seed_hosts: ${seed_hosts}
cluster.initial_master_nodes: ${initial_master_nodes}

cluster.routing.allocation.awareness.attributes: aws_availability_zone
cluster.routing.allocation.awareness.force.aws_availability_zone.values: us-west-2a,us-west-2b

xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true
xpack.security.transport.ssl.keystore.path: certs/elastic-certificates.p12
xpack.security.transport.ssl.truststore.path: certs/elastic-certificates.p12

path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
```

### logstash pipeline config (via Terraform templatefile)

```
input {
  beats {
    port => 5044
    ssl => true
    ssl_certificate => "/etc/logstash/certs/logstash.crt"
    ssl_key => "/etc/logstash/certs/logstash.key"
  }
}

filter {
  if [type] == "syslog" {
    grok { match => { "message" => "%{SYSLOGTIMESTAMP:syslog_timestamp} %{SYSLOGHOST:syslog_hostname} %{DATA:syslog_program}: %{GREEDYDATA:syslog_message}" } }
    date { match => [ "syslog_timestamp", "MMM  d HH:mm:ss", "MMM dd HH:mm:ss" ] }
  }
  if [type] == "winlogbeat" {
    mutate { add_field => { "[@metadata][index_prefix]" => "logs-windows" } }
  }
  if [type] == "cloudtrail" {
    json { source => "message" }
    mutate { add_field => { "[@metadata][index_prefix]" => "logs-cloudtrail" } }
  }
  geoip { source => "source.ip" target => "source.geo" }
}

output {
  elasticsearch {
    hosts => ["${es_endpoint}:9200"]
    user => "${es_user}"
    password => "${es_password}"
    index => "%{[@metadata][index_prefix]:logs-generic}-%{+YYYY.MM.dd}"
    ssl => true
    cacert => "/etc/logstash/certs/ca.crt"
  }
}
```

### kibana.yml (via Terraform templatefile)

```yaml
server.port: 5601
server.host: "0.0.0.0"
elasticsearch.hosts: ["https://${es_endpoint}:9200"]
elasticsearch.username: "${kibana_user}"
elasticsearch.password: "${kibana_password}"
elasticsearch.ssl.certificateAuthorities: ["/etc/kibana/certs/ca.crt"]
xpack.security.enabled: true
xpack.encryptedSavedObjects.encryptionKey: "${encryption_key}"
xpack.reporting.encryptionKey: "${reporting_key}"
xpack.security.session.idleTimeout: "1h"
logging.dest: /var/log/kibana/kibana.log
```

---

## 5. IAM — Roles and Policies

Each EC2 tier gets its own instance profile. No shared roles.

### Logstash role — `role-siem-logstash`

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:us-west-2:ACCOUNT:secret:siem/logstash/*"
    }
  ]
}
```

### Elasticsearch role — `role-siem-elasticsearch`

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::SNAPSHOT_BUCKET",
        "arn:aws:s3:::SNAPSHOT_BUCKET/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["kms:GenerateDataKey", "kms:Decrypt"],
      "Resource": "arn:aws:kms:us-west-2:ACCOUNT:key/CMK_ID"
    },
    {
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:us-west-2:ACCOUNT:secret:siem/elasticsearch/*"
    }
  ]
}
```

### Kibana role — `role-siem-kibana`

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:us-west-2:ACCOUNT:secret:siem/kibana/*"
    },
    {
      "Effect": "Allow",
      "Action": ["cloudwatch:PutMetricData"],
      "Resource": "*"
    }
  ]
}
```

---

## 6. KMS

- One customer-managed key per environment
- Key rotation enabled: `enable_key_rotation = true`
- Key policy: deny `kms:*` to root except dedicated admin role
- Used for: EBS volumes on all EC2 instances, S3 snapshot bucket SSE-KMS
- Alias: `alias/siem-${var.environment}`

---

## 7. Secrets Manager

| Secret name | Contents | Rotation |
|-------------|----------|----------|
| `siem/elasticsearch/master-password` | ES built-in superuser password | Stub rotation lambda |
| `siem/logstash/es-credentials` | `{"user":"logstash_internal","password":"..."}` | Manual |
| `siem/kibana/es-credentials` | `{"user":"kibana_system","password":"..."}` | Manual |
| `siem/tls/ca-cert` | PEM CA certificate | Manual |
| `siem/tls/logstash-cert` | Logstash TLS cert + key | Manual |

Secrets are fetched in `user_data` scripts using `aws secretsmanager get-secret-value`. Never passed as Terraform variables or environment variables.

---

## 8. S3

### Snapshot bucket

- Name: `siem-es-snapshots-${var.environment}-${data.aws_caller_identity.current.account_id}`
- `block_public_acls = true`
- `block_public_policy = true`
- `ignore_public_acls = true`
- `restrict_public_buckets = true`
- SSE-KMS with the project CMK
- Versioning enabled
- Lifecycle rule: transition to Glacier after 30 days, delete after 365 days
- Bucket policy restricts PutObject/GetObject to `role-siem-elasticsearch` only

---

## 9. Load Balancers

### NLB — Beats ingest

- Type: Network Load Balancer, internal-facing
- Listener: TCP 5044, TLS termination using ACM cert
- Target group: Logstash instances, port 5044, health check TCP
- Cross-zone load balancing: enabled

### ALB — Kibana

- Type: Application Load Balancer, internet-facing
- Listener: HTTPS 443, ACM cert
- Target group: Kibana instance, port 5601, health check `/api/status`
- WAF WebACL attached: IP allowlist rule using `var.allowed_analyst_ips`
- HTTP 80 → 301 redirect to HTTPS

---

## 10. Elasticsearch ILM Policy

Apply to all `logs-*` index templates via Kibana API or `null_resource` + `curl` in Terraform.

```json
{
  "policy": {
    "phases": {
      "hot":  { "min_age": "0ms", "actions": { "rollover": { "max_size": "50gb", "max_age": "1d" } } },
      "warm": { "min_age": "7d",  "actions": { "shrink": { "number_of_shards": 1 }, "forcemerge": { "max_num_segments": 1 } } },
      "cold": { "min_age": "30d", "actions": { "freeze": {} } },
      "delete": { "min_age": "90d", "actions": { "delete": {} } }
    }
  }
}
```

---

## 11. CloudWatch

- VPC flow logs: ALL traffic → CW log group `/siem/vpc-flow-logs` + S3 bucket
- CloudWatch agent on all EC2 instances: cpu, mem, disk metrics
- Log groups: `/siem/logstash`, `/siem/elasticsearch`, `/siem/kibana`

### Alarms to create

| Alarm | Metric | Threshold | Action |
|-------|--------|-----------|--------|
| ES cluster health RED | `ElasticsearchRequests` — proxy via custom metric | Status = RED for 5 min | SNS alert |
| Logstash queue depth | Custom metric from Logstash monitoring API | > 10000 events | SNS alert |
| EC2 CPU high | `CPUUtilization` | > 85% for 5 min | SNS alert |
| Disk space low | Custom CW agent metric | > 80% used | SNS alert |
| NLB unhealthy hosts | `UnHealthyHostCount` | > 0 | SNS alert |

---

## 12. Terraform Variables Reference

All required variables must be set before `terraform plan`. No defaults on required vars — fail loudly if missing.

```hcl
# versions.tf — pin these
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    tls = { source = "hashicorp/tls", version = "~> 4.0" }
  }
  required_version = ">= 1.6.0"
}
```

| Variable | Type | Default | Required | Notes |
|----------|------|---------|----------|-------|
| `aws_region` | string | `us-west-2` | no | |
| `environment` | string | — | yes | e.g. `staging`, `prod` |
| `vpc_cidr` | string | `10.0.0.0/16` | no | |
| `availability_zones` | list(string) | `["us-west-2a","us-west-2b"]` | no | |
| `es_master_instance_type` | string | `r5.large` | no | |
| `es_data_instance_type` | string | `r5.xlarge` | no | |
| `logstash_instance_type` | string | `c5.large` | no | |
| `kibana_instance_type` | string | `t3.large` | no | |
| `ami_id` | string | — | yes | Amazon Linux 2023 or hardened AMI |
| `key_pair_name` | string | — | yes | For bastion SSH |
| `allowed_analyst_ips` | list(string) | — | yes | WAF allowlist for Kibana |
| `beats_source_cidrs` | list(string) | — | yes | NLB SG ingress for Beats agents |
| `trusted_cidr_blocks` | list(string) | — | yes | Bastion SSH access |
| `alert_email` | string | — | yes | SNS alarm destination |
| `retention_hot_days` | number | `7` | no | ES ILM hot phase |
| `retention_warm_days` | number | `30` | no | ES ILM warm phase |
| `retention_delete_days` | number | `90` | no | ES ILM delete phase |
| `snapshot_glacier_days` | number | `30` | no | S3 lifecycle Glacier transition |
| `snapshot_delete_days` | number | `365` | no | S3 lifecycle delete |

---

## 13. Implementation Order for Codex

Work through tasks in this sequence. Do not skip forward — each phase depends on the previous.

### Phase 1 — Foundation

- [ ] `versions.tf` — pin provider versions
- [ ] Remote state backend — S3 bucket + DynamoDB lock table (create manually before init)
- [ ] `modules/kms` — CMK, key rotation, key policy, alias
- [ ] `modules/iam` — all roles, policies, instance profiles
- [ ] `modules/secrets` — Secrets Manager entries (placeholder secret values)
- [ ] `modules/vpc` — VPC, 6 subnets, IGW, 2x NAT GW, route tables, VPC flow logs
- [ ] `modules/sg` — all security groups per section 2 above
- [ ] `modules/s3` — snapshot bucket with all hardening settings

**Validate before proceeding:** `terraform validate` passes, `terraform plan` shows 0 errors, no `*` wildcards in any IAM policy Action or Resource.

### Phase 2 — ELK Core

- [ ] `modules/ec2_elk` — ES master nodes x2
- [ ] `modules/ec2_elk` — ES data nodes x4 (2 hot AZ-a, 2 warm AZ-b)
- [ ] `elasticsearch.yml` templatefile per node role — inject AZ attribute, cluster seed hosts from outputs
- [ ] `modules/ec2_elk` — Logstash x2, one per AZ
- [ ] Logstash pipeline config templatefile — syslog, winlogbeat, cloudtrail inputs + GeoIP enrichment
- [ ] `modules/ec2_elk` — Kibana x1
- [ ] `kibana.yml` templatefile — xpack security, ES endpoint from outputs
- [ ] `modules/nlb` — Beats NLB, port 5044, TLS, Logstash target group
- [ ] `modules/alb` — Kibana ALB, HTTPS, WAF WebACL with analyst IP allowlist

**Validate before proceeding:** ES cluster health GREEN (`curl -u elastic:pass https://ES_IP:9200/_cluster/health`), Kibana reachable at ALB DNS on port 443, Logstash pipeline shows `events.out > 0`.

### Phase 3 — Observability

- [ ] `modules/cloudwatch` — log groups for each service
- [ ] CloudWatch agent config on all EC2 instances (cpu, mem, disk)
- [ ] VPC flow log delivery to CloudWatch + S3
- [ ] SNS topic + subscriptions for `var.alert_email`
- [ ] All CloudWatch alarms from section 11
- [ ] ES ILM policy applied to `logs-*` index template
- [ ] ES snapshot repository registered pointing to S3 bucket
- [ ] Snapshot lifecycle policy — daily snapshot at 02:00 UTC, retain 30

**Validate before proceeding:** all CloudWatch alarms in `OK` state, ILM policy visible in Kibana Stack Management, snapshot repository status `green`.

---

## 14. Security Non-Negotiables

These are hard requirements. Do not defer, work around, or mark as TODO.

- KMS encryption on every EBS volume and the S3 snapshot bucket before any data is written
- No SG rule with source `0.0.0.0/0` except ALB port 443
- No plaintext credentials anywhere — user_data, env vars, tfvars, or Terraform state
- `block_public_access` all four flags true on every S3 bucket
- VPC flow logs enabled and delivering before any EC2 instance is launched
- All EC2 `user_data` scripts must be idempotent
- All resources tagged: `Name`, `project = "elk-siem"`, `environment = var.environment`

---

## 15. Open Decisions

These need answers before or during Phase 2. Flag and block on them rather than guessing.

| # | Decision | Options |
|---|----------|---------|
| OD-1 | ACM cert — use existing cert ARN or create new via `aws_acm_certificate` + DNS validation? | Provide `var.acm_cert_arn` or add ACM module |
| OD-2 | ES version — 8.x OSS vs licensed basic (free tier includes SIEM features)? | Recommend 8.x basic; confirm before baking AMI |
| OD-3 | Bastion — persistent EC2 vs SSM Session Manager only (no port 22 SG rule)? | SSM preferred; removes need for sg_bastion and key pair |
| OD-4 | Logstash pipeline configs — store in S3 and pull at boot, or bake into AMI? | S3 pull preferred for easier config updates |
| OD-5 | ES inter-node TLS — self-signed CA via `tls` Terraform provider or bring your own cert? | Self-signed CA is fine for internal cluster traffic |
