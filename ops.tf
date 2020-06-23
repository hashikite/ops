resource "github_repository" "ops" {
	name         = "ops"
	description  = "Terrraforming the world to have more kites and more feelings 🌏🪁✨"
	homepage_url = "https://buildkite.com/hashikite/ops"
	topics       = ["buildkite", "terraform", "example"]

	has_downloads = false

	delete_branch_on_merge = true
}

resource "github_repository_webhook" "ops-buildkite" {
	repository = github_repository.ops.name
	events     = ["push", "pull_request"]
	configuration {
		url        = buildkite_pipeline.ops.webhook_url
		content_type = "json"
	}
}

resource "buildkite_pipeline" "ops" {
	name        = "Ops"
	slug        = "ops"
	description = "Terrraforming the world to have more kites and more feelings 🌏🪁✨"
	repository  = github_repository.ops.http_clone_url

	branch_configuration = "master"

	github_settings {
		trigger_mode        = "code"
		build_pull_requests = true
	}

	step {
		type    = "script"
		name    = ":pipeline:"
		command = "buildkite-agent pipeline upload"
	}
}

resource "aws_s3_bucket" "ops" {
	bucket = "ops.production.hashikite.net"
	acl    = "private"
	versioning {
		enabled = true
	}
}

data "aws_ssm_parameter" "buildkite-agent-ops-token" {
	name = "/ops/buildkite-agent/BUILDKITE_AGENT_TOKEN"
}

resource "aws_cloudwatch_log_group" "buildkite-agent-ops" {
	name = "/ops/buildkite-agent"
}

resource "aws_ecr_repository" "buildkite-agent-ops" {
	name = "buildkite-agent-ops"
}

resource "aws_ecs_task_definition" "buildkite-agent-ops" {
	family             = "buildkite-agent-ops"
	execution_role_arn = aws_iam_role.buildkite-agent-ops.arn
	task_role_arn      = aws_iam_role.buildkite-agent-ops.arn
	cpu                = 256
	memory             = 512

	network_mode             = "awsvpc"
	requires_compatibilities = ["FARGATE"]

	container_definitions = jsonencode([
		{
			name         = "buildkite-agent",
			image        = aws_ecr_repository.buildkite-agent-ops.repository_url,
			essential    = true,
			cpu          = 0,

			environment  = [
				{ name = "BUILDKITE_AGENT_NAME", value = "buldkite-agent-ops-%h-%i" },
				{ name = "BUILDKITE_AGENT_TAGS", value = "queue = ops" },
			],
			secrets = [
				{ name = "BUILDKITE_AGENT_TOKEN", valueFrom = data.aws_ssm_parameter.buildkite-agent-ops-token.name },
			],

			mountPoints            = [],
			volumesFrom            = [],
			readonlyRootFilesystem = false,

			logConfiguration            = {
				logDriver                 = "awslogs",
				options                   = {
					"awslogs-group"         = aws_cloudwatch_log_group.buildkite-agent-ops.name,
					"awslogs-region"        = data.aws_region.primary.name,
					"awslogs-stream-prefix" = "buildkite-agent",
				},
			},
		},
	])

	tags = {}
}

resource "aws_iam_role" "buildkite-agent-ops" {
	name               = "BuildkiteAgentOpsTaskRole"
	assume_role_policy = data.aws_iam_policy_document.ecs-assume-role-policy.json
}

resource "aws_iam_role_policy_attachment" "buildkite-agent-ops-task" {
	role = aws_iam_role.buildkite-agent-ops.name
	policy_arn = data.aws_iam_policy.ecs-task-policy.arn
}

resource "aws_iam_role_policy" "buildkite-agent-ops-terraform" {
	name        = "Terraform"
	role        = aws_iam_role.buildkite-agent-ops.name
	policy      = jsonencode({
		Version   = "2012-10-17",
		Statement = [
			{
				Sid    = "0",
				Action = [
					"acm:*",
					"cloudformation:*",
					"ec2:*",
					"ecr:*",
					"ecs:*",
					"elasticloadbalancing:*",
					"iam:Describe*",
					"iam:Get*",
					"iam:List*",
					"logs:*",
					"route53:*",
					"s3:*",
					"ssm:*",
				],
				Effect   = "Allow",
				Resource = "*",
			},
		],
	})
}

resource "aws_ecs_service" "buildkite-agent-ops" {
	name            = "buildkite-agent-ops"
	cluster         = aws_ecs_cluster.production.id
	task_definition = "${aws_ecs_task_definition.buildkite-agent-ops.family}:${aws_ecs_task_definition.buildkite-agent-ops.revision}"
	launch_type     = "FARGATE"
	desired_count   = 1
	
	network_configuration {
		subnets = module.vpc.private_subnets
	}
}
