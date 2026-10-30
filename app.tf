resource "aws_ecr_repository" "app" {
  name = "app"
}

resource "aws_cloudwatch_log_group" "app" {
  name = "/app"
}
