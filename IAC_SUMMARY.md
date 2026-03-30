# AWS ELK SIEM IaC Summary (Terraform)

This repo provisions a small, multi-AZ ELK SIEM on AWS using Terraform, with supporting networking, security groups, encryption, secrets, load balancers, and monitoring.

## Layout

- `bootstrap/`: Terraform backend prerequisites (S3 remote state bucket + DynamoDB lock table)
- `elk-siem/`: Main infrastructure stack (modules orchestrated from `elk-siem/main.tf`)
- `.github/workflows/tfsec.yml`: Trivy config scan in CI (IaC misconfigurations)

## How to Deploy (high level)

1. Deploy `bootstrap/` first (creates remote state bucket + lock table).
2. Configure the backend for `elk-siem/` (S3 backend block in `elk-siem/versions.tf`).
3. Populate `elk-siem/terraform.tfvars` (see `elk-siem/terraform.tfvars.example`).
4. `terraform init && terraform plan && terraform apply` in `elk-siem/`.

## Root Inputs (what you set)

Defined in `elk-siem/variables.tf`:

- `environment`: used in naming/tagging (validated to `^[a-z0-9-]+$`)
- `aws_region`: defaults `us-west-2`
- `account_id`: optional; if empty, derived via `aws_caller_identity` (used to build deterministic bucket names)
- `ami_id`: AMI for all EC2 instances (templates support Ubuntu 24.04 and dnf-based distros)
- Network allowlists:
  - `beats_source_cidrs`: who can send Beats to Logstash on `5044`
  - `vpn_cidr_blocks`: who can reach Kibana privately on `5601`
  - `allowed_analyst_ips`: only used if `enable_public_kibana=true` (WAF allowlist)
- Alerts:
  - `alert_email`: subscribes to an SNS topic for alarms
- KMS:
  - `kms_admin_principal_arn`: IAM principal that can administer the SIEM KMS key
- Sizing knobs:
  - instance types for ES master/data, Logstash, Kibana
  - volume sizes for ES root/data, Logstash root, Kibana root
- Optional public Kibana:
  - `enable_public_kibana` (default `false`)
  - `acm_cert_arn` required if enabled

## Module Orchestration (what gets created)

`elk-siem/main.tf` composes modules in dependency order:

### 1) `module.kms` (`elk-siem/modules/kms`)

- Creates a customer-managed KMS key (`aws_kms_key`) + alias for encrypting:
  - EBS volumes on EC2 instances
  - S3 objects (snapshot bucket + flow logs bucket)
  - SNS topic (alerts)
- Key policy:
  - root of the account gets full admin
  - `kms_admin_principal_arn` gets full admin
  - allows in-account IAM delegation for common KMS actions
  - optional allowance for AWS log delivery service using SSE-KMS for specific S3 buckets

### 2) `module.iam` (`elk-siem/modules/iam`)

Creates dedicated instance roles + instance profiles:

- `role-siem-elasticsearch-*` (+ instance profile)
  - SSM managed instance core
  - CloudWatch agent policy
  - Secrets Manager read access for `siem/elasticsearch/*` and `siem/tls/*`
  - S3 snapshot bucket access
  - KMS decrypt/encrypt/data key for snapshots
  - CloudWatch `PutMetricData`
- `role-siem-logstash-*` (+ instance profile)
  - SSM + CloudWatch agent
  - Secrets Manager read access for `siem/logstash/*` and `siem/tls/*`
- `role-siem-kibana-*` (+ instance profile)
  - SSM + CloudWatch agent
  - Secrets Manager read access for `siem/kibana/*` and `siem/tls/*`
  - CloudWatch `PutMetricData`

### 3) `module.secrets` (`elk-siem/modules/secrets`)

Creates Secrets Manager secrets used by user-data bootstrapping:

- `siem/elasticsearch/master-password`
- `siem/logstash/es-credentials`
- `siem/kibana/es-credentials`
- TLS materials under `siem/tls/*` (CA cert, Logstash cert, Kibana cert, Elasticsearch cert/key JSON)

Each secret gets a resource policy so only the relevant instance role(s) can read it.

Secret values are generated and written by Terraform via `aws_secretsmanager_secret_version`:

- Passwords are generated with the `random` provider.
- TLS materials are generated with the `tls` provider (self-signed CA + locally-signed leaf certs).

### 4) `module.vpc` (`elk-siem/modules/vpc`)

Builds a 2-AZ VPC with:

- Public subnets (A/B) with `map_public_ip_on_launch = true`
- Private ingestion subnets (A/B) for Logstash
- Private ELK subnets (A/B) for Elasticsearch + Kibana
- Internet Gateway
- One NAT Gateway per AZ + private route tables to keep egress available for private subnets
- Public route table for public subnets

Outputs:

- `vpc_id`, `public_subnet_ids`, `private_ingestion_subnet_ids`, `private_elk_subnet_ids`

### 5) `module.sg` (`elk-siem/modules/sg`)

Creates security groups (egress open by design):

- NLB SG: ingress `5044` from `beats_source_cidrs`
- Logstash SG: ingress `5044` from NLB SG
- Kibana SG: ingress `5601` from `vpn_cidr_blocks`
- Elasticsearch SG:
  - `9200` and `9300` from Logstash SG
  - `9200` from Kibana SG
  - `9300` self (cluster transport)
- ALB SG (reserved for optional public Kibana): ingress is added by ALB module when enabled

### 6) `module.s3` (`elk-siem/modules/s3`)

Elasticsearch snapshot bucket:

- Private bucket, public access blocked
- Versioning enabled
- SSE-KMS with the SIEM CMK
- Lifecycle transitions to Glacier + expiration controlled by:
  - `snapshot_glacier_days`, `snapshot_delete_days`
- Bucket policy grants the Elasticsearch role list/get/put access

### 7) `module.cloudwatch` (`elk-siem/modules/cloudwatch`)

Observability and delivery:

- CloudWatch log groups for:
  - VPC flow logs, Logstash, Elasticsearch, Kibana
- VPC flow logs delivered to:
  - CloudWatch Logs (via IAM role)
  - S3 bucket (SSE-KMS enabled)
- SNS topic `siem-alerts-*` encrypted with KMS + email subscription
- CloudWatch alarms:
  - Elasticsearch cluster health (custom metric)
  - Logstash queue depth (custom metric)

### 8) `module.ec2_elk` (`elk-siem/modules/ec2_elk`)

EC2 instances:

- Elasticsearch masters: 2 (one per AZ)
- Elasticsearch data nodes: 4 (hot/warm tiers)
- Logstash: 2 (one per AZ)
- Kibana: 1 (in private ELK subnet B)

Security & encryption:

- All EBS volumes encrypted with the SIEM KMS CMK
- IMDSv2 enforced: `metadata_options { http_tokens = "required" }` on all instances

Bootstrapping via `user_data` templates:

- Elasticsearch:
  - installs Elastic packages
  - enables TLS and sets bootstrap password via keystore
  - installs `repository-s3` plugin
  - publishes cluster health metric to CloudWatch on a timer (uses IMDSv2 token)
- Logstash:
  - installs Logstash
  - configures Beats input on `5044` with TLS
  - outputs to Elasticsearch over HTTPS
  - publishes queue depth metric to CloudWatch on a timer (uses IMDSv2 token)
- Kibana:
  - installs Kibana
  - configures HTTPS with TLS from Secrets Manager
  - generates and persists Kibana encryption/reporting keys locally

### 9) `module.nlb` (`elk-siem/modules/nlb`)

Beats ingest NLB:

- NLB listener on `5044/TCP`
- Target group attaches Logstash instances
- `internal` controlled by `nlb_internal` (defaults to `true`)

Output:

- `nlb_dns_name` (from root `elk-siem/outputs.tf`)

### 10) `module.alb` (`elk-siem/modules/alb`) (optional)

Only created when `enable_public_kibana=true`:

- Internet-facing ALB
- HTTPS listener on `443` using `acm_cert_arn`
- HTTP `80` redirects to HTTPS
- WAFv2 allowlist using `allowed_analyst_ips`
- Target group forwards to Kibana on `5601` (configured as `HTTPS`)

## Operational Add-on: Elasticsearch Ops via SSM

`elk-siem/ops.tf` creates:

- An SSM document that configures:
  - ILM policy
  - Snapshot repository (S3)
  - SLM policy (scheduled snapshots)
- SSM association targeting one ES master instance

The document retrieves region via IMDSv2 token and pulls the Elasticsearch master password from Secrets Manager.

## Key Outputs (for operators)

From `elk-siem/outputs.tf`:

- `nlb_dns_name`: send Beats to this address on port `5044`
- `kibana_private_ip`: Kibana’s private IP (for VPN/private access)
- Elasticsearch node private IPs
- `snapshot_bucket_name`, `kms_key_arn`, plus subnet/VPC outputs

## Security Notes / Design Decisions

- Private subnets use NAT for outbound access.
- Security group egress is open by design (documented; allowlisted in Trivy allowlist).
- Public subnets intentionally map public IPs (documented; allowlisted in Trivy allowlist).
- IMDSv2 required on all EC2.
- Secrets are stored in AWS Secrets Manager and scoped with per-secret resource policies.
- Encryption:
  - SSE-KMS for S3 buckets
  - KMS encryption for EBS volumes
  - SNS topic encrypted with KMS
