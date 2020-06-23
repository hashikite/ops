resource "aws_iam_policy" "buildkite-agents-app" {
  name        = "BuildkiteAgentsPolicy"
  description = "Permissions for instances running buildkite-agent processes"
  policy      = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Sid    = "0",
        Action = [
          # Allow pushing new versions to ECR repositories
          "ecr:*",
          # Allow deploying new version of ECS services
          "ecs:*",
        ],
        Effect   = "Allow",
        Resource = "*",
      },
    ],
  })
}


resource "aws_cloudformation_stack" "buildkite-agents" {
  name = "buildkite-agents"

  parameters = {
    BuildkiteAgentTokenParameterStorePath = "/ops/buildkite-agent/BUILDKITE_AGENT_TOKEN"

    InstanceType      = "t3.small"
    AgentsPerInstance = 1
    ManagedPolicyARN  = aws_iam_policy.buildkite-agents-app.arn
    ECRAccessPolicy   = "full"
    MinSize           = 1
    MaxSize           = 10
  }

  capabilities = ["CAPABILITY_NAMED_IAM"]
  template_url = "https://s3.amazonaws.com/buildkite-aws-stack/master/281035920abb0a81ff1905148839792850d3e3c1.aws-stack.yml"
}
