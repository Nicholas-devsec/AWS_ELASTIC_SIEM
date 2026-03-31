locals {
  ilm_json_b64 = base64encode(jsonencode({
    policy = {
      phases = {
        hot = {
          min_age = "0ms"
          actions = {
            rollover = { max_size = "50gb", max_age = "1d" }
          }
        }
        warm = {
          min_age = format("%dd", var.retention_hot_days)
          actions = {
            shrink     = { number_of_shards = 1 }
            forcemerge = { max_num_segments = 1 }
          }
        }
        cold = {
          min_age = format("%dd", var.retention_warm_days)
          actions = { freeze = {} }
        }
        delete = {
          min_age = format("%dd", var.retention_delete_days)
          actions = { delete = {} }
        }
      }
    }
  }))

  snapshot_repo_json_b64 = base64encode(jsonencode({
    type = "s3"
    settings = {
      bucket = local.snapshot_bucket_name
      region = var.aws_region
    }
  }))

  slm_json_b64 = base64encode(jsonencode({
    schedule   = "0 0 2 * * ?"
    name       = "<siem-snap-{now/d}>"
    repository = "siem-snapshots"
    config = {
      indices              = ["logs-*"]
      ignore_unavailable   = true
      include_global_state = true
    }
    retention = {
      expire_after = "30d"
      min_count    = 1
      max_count    = 30
    }
  }))
}

resource "aws_ssm_document" "siem_es_ops" {
  name            = "siem-es-ops-${var.environment}"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Configure Elasticsearch ILM, snapshot repository, and SLM for SIEM."
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "configure"
        inputs = {
          runCommand = [
            "set -euo pipefail",
            "TOKEN=$(curl -sS -X PUT http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600')",
            "REGION=$(curl -sS -H \"X-aws-ec2-metadata-token: $TOKEN\" http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)",
            "ELASTIC_PASS=$(aws --region \"$REGION\" secretsmanager get-secret-value --secret-id \"siem/elasticsearch/master-password\" --query SecretString --output text)",
            "CACERT=/etc/elasticsearch/certs/ca.crt",
            "BASE=https://localhost:9200",
            "",
            "mkdir -p /opt/siem",
            "echo '${local.ilm_json_b64}' | base64 -d >/opt/siem/ilm.json",
            "",
            "curl -sS --fail --cacert \"$CACERT\" -u \"elastic:$ELASTIC_PASS\" -X PUT \"$BASE/_ilm/policy/logs-default\" -H 'Content-Type: application/json' --data-binary @/opt/siem/ilm.json >/dev/null",
            "",
            "echo '${local.snapshot_repo_json_b64}' | base64 -d >/opt/siem/snapshot_repo.json",
            "curl -sS --fail --cacert \"$CACERT\" -u \"elastic:$ELASTIC_PASS\" -X PUT \"$BASE/_snapshot/siem-snapshots\" -H 'Content-Type: application/json' --data-binary @/opt/siem/snapshot_repo.json >/dev/null",
            "",
            "echo '${local.slm_json_b64}' | base64 -d >/opt/siem/slm.json",
            "curl -sS --fail --cacert \"$CACERT\" -u \"elastic:$ELASTIC_PASS\" -X PUT \"$BASE/_slm/policy/siem-daily\" -H 'Content-Type: application/json' --data-binary @/opt/siem/slm.json >/dev/null",
            ""
          ]
        }
      }
    ]
  })
}

resource "aws_ssm_association" "siem_es_ops" {
  name = aws_ssm_document.siem_es_ops.name

  targets {
    key    = "InstanceIds"
    values = [module.ec2_elk.es_master_instance_ids["a"]]
  }
}
