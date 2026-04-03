# AWS SIEM Lab (Elastic Stack on EC2, Terraform)

This repo is a hands-on SIEM lab build in AWS: Elasticsearch + Logstash + Kibana on EC2, segmented into public/ingestion/cluster subnets, with Secrets Manager, KMS encryption, VPC flow logs, and S3 snapshots. The goal is a realistic security engineering exercise you can stand up, validate with real events, take screenshots, and tear down quickly.

![Architecture Diagram](images/Draw_IO_diagram.png)

## What this build optimizes for

- **Private-first access**: Kibana is reachable via SSM port-forward by default; no public ingress required.
- **Defense-in-depth basics**: KMS for at-rest encryption (EBS/S3/Secrets), restricted security groups, and VPC flow logs.
- **Operational simplicity**: Everything bootstraps from user-data, pulls secrets at boot, and avoids manual “click ops” where possible.
- **Cost control**: Dev-friendly destroy behavior (force-destroy buckets, short secret recovery windows) so the lab doesn’t linger.

## Data path (how logs move)

`Filebeat (demo host)` → `internal NLB :5044 (TCP)` → `Logstash` → `Elasticsearch (HTTPS :9200)` → `Kibana (HTTPS :5601)`

Kibana is not in the ingest path; it reads from Elasticsearch.

## Key engineering decisions (and why)

- **No ACM + no public Kibana by default**
  - Kibana is private by default. Operator access is **SSM port-forward → `https://localhost:5601`**.
  - A public entry point is supported, but it assumes you already have DNS + an ACM cert. If you want that, set `enable_public_kibana=true` and provide `acm_cert_arn`.

- **TLS where it matters most**
  - Elasticsearch runs TLS for HTTP (`:9200`) and transport (`:9300`).
  - Beats → Logstash is **plain TCP inside the VPC** in this lab build.

- **Beats over 5044 (tradeoff)**
  - We hit a real-world bootstrap issue on `:5044`: Filebeat couldn’t deliver because Logstash crash-looped when its Beats input expected a cert/key that never landed on disk.
  - For this lab, the pragmatic call was to keep `:5044` inside the VPC and make it reliable (TCP pass-through on the internal NLB, plain Beats input on Logstash).
  - Recommended approach for anything beyond a lab is **TLS (preferably mTLS)** on Beats/Agent → Logstash.

- **Secrets are pulled at boot**
  - Instances use IAM instance profiles + SSM, and fetch Secrets Manager values during user-data.
  - This keeps sensitive values out of the repo and avoids baking credentials into AMIs.

- **Backups are real (and cheap over time)**
  - Elasticsearch snapshots go to a dedicated S3 bucket with SSE-KMS + versioning.
  - Lifecycle defaults: **Glacier after 30 days**, delete after **365 days**.

## Lab vs prod (what I’d change)

- **Beats transport**: enable mTLS (Beats/Agent → Logstash) and validate the chain, instead of plain TCP.
- **Kibana access**: put Kibana behind ALB + WAF with an ACM cert + DNS, rather than relying on port-forwarding.
- **Host hardening**: CIS baseline, tighter egress controls, patching strategy, and stricter IAM scoping.

### If you want to re-enable TLS on Beats → Logstash

The NLB stays L4 TCP; Logstash terminates TLS. Repo changes:

- `elk-siem/modules/ec2_elk/templates/user_data_logstash.sh.tftpl`: restore Beats input TLS (`ssl_certificate`/`ssl_key`) and fetch the cert/key from Secrets Manager (e.g. `siem/tls/logstash-cert`).
- `elk-siem/modules/ec2_elk/main.tf`: pass the Logstash TLS secret name back into the template variables.
- `elk-siem/modules/beats_demo/templates/user_data_filebeat.sh.tftpl`: set `output.logstash.ssl.enabled: true` and trust the CA (either `ssl.certificate_authorities` or a pinned CA bundle file).

## Repo layout

- `bootstrap/`: Remote Terraform backend (S3 state bucket + DynamoDB lock table + KMS key).
- `elk-siem/`: Main stack (VPC, EC2, internal Beats NLB, Secrets Manager, snapshot bucket, flow logs, alarms).
- `images/`: Diagrams and screenshots used in this write-up.

## Screenshots (examples)

SSM managed nodes (shows the fleet is reachable via Session Manager):

![SSM Managed Nodes](images/managed_nodes.png)

![Example Logs](images/example_siem_logs_good.png)

![AWS Resource Map](images/SIEM_rerouce_map.png)

## Minimal “how to run it”

You’ll configure values in `elk-siem/terraform.tfvars`, then:

```bash
cd bootstrap && terraform init && terraform apply
cd ../elk-siem && terraform init -reconfigure && terraform apply
```

## Tear down

```bash
cd elk-siem && terraform destroy
cd ../bootstrap && terraform destroy
```

Expect some resources (notably KMS keys) to sit in “pending deletion” for a while by design.
