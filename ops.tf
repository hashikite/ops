resource "aws_s3_bucket" "ops" {
  bucket = "ops.production.hashikite.net"
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_cloudwatch_log_group" "buildkite-agent-ops" {
  name = "/ops/buildkite-agent"
}

resource "aws_ecr_repository" "buildkite-agent-ops" {
  name = "buildkite-agent-ops"
}
