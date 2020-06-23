resource "github_repository" "app" {
	name         = "app"
	description  = "Hashing feelings into kites"
	homepage_url = "http://hashikite.com"
	
	delete_branch_on_merge = true
}

resource "github_repository_webhook" "app-buildkite" {
	repository = github_repository.app.name
	events     = ["push", "pull_request"]
	configuration {
		url          = buildkite_pipeline.app.webhook_url
		content_type = "json"
	}
}

resource "buildkite_pipeline" "app" {
	name       = "app"
	repository = github_repository.app.http_clone_url

	env = {
		"DOMAIN"  = aws_route53_zone.production.name,

		"ECR_URL" = aws_ecr_repository.app.repository_url,

		"ECS_CLUSTER" = aws_ecs_service.app.cluster,
		"ECS_SERVICE" = aws_ecs_service.app.name,
	}

	step {
		type    = "script"
		name    = ":pipeline:"
		command = "buildkite-agent pipeline upload"
	}
}

resource "aws_ecr_repository" "app" {
	name = "app"
}

resource "aws_cloudwatch_log_group" "app" {
	name = "/app"
}

resource "aws_iam_role" "app" {
	name               = "AppTaskRole"
	assume_role_policy = data.aws_iam_policy_document.ecs-assume-role-policy.json
}

resource "aws_iam_role_policy_attachment" "app-ecs" {
	role = aws_iam_role.app.name
	policy_arn = data.aws_iam_policy.ecs-task-policy.arn
}

resource "aws_ecs_task_definition" "app" {
	family             = "app"
	execution_role_arn = aws_iam_role.app.arn
	task_role_arn      = aws_iam_role.app.arn
	cpu                = 256
	memory             = 512

	network_mode             = "awsvpc"
	requires_compatibilities = ["FARGATE"]

	container_definitions = jsonencode([
		{
			name              = "app",
			image             = aws_ecr_repository.app.repository_url,
			essential         = true,
			cpu               = 0,

			environment       = [],

			portMappings      = [
				{
					containerPort = 8080,
					hostPort      = 8080,
					protocol      = "tcp",
				},
			],

			mountPoints = [],
			volumesFrom = [],

			logConfiguration            = {
				logDriver                 = "awslogs",
				options                   = {
					"awslogs-group"         = aws_cloudwatch_log_group.app.name,
					"awslogs-region"        = data.aws_region.primary.name,
					"awslogs-stream-prefix" = "app",
				},
			},
		}
	])
}

resource "aws_ecs_service" "app" {
	name            = "app"
	cluster         = aws_ecs_cluster.production.id
	task_definition = "${aws_ecs_task_definition.app.family}:${aws_ecs_task_definition.app.revision}"
	launch_type     = "FARGATE"
	desired_count   = 1

	network_configuration {
		subnets = module.vpc.private_subnets
	}

	load_balancer {
		target_group_arn = aws_lb_target_group.production-app.arn
		container_name   = "app"
		container_port   = 8080
	}
}

resource "aws_lb" "production" {
	name    = "production"
	subnets = module.vpc.public_subnets
}

resource "aws_lb_listener" "production-http" {
	load_balancer_arn = aws_lb.production.arn
	port              = "80"
	protocol          = "HTTP"

	default_action {
		type = "redirect"
		redirect {
			port = 443
			protocol    = "HTTPS"
			status_code = "HTTP_301"
		}
	}
}

resource "aws_lb_listener" "production-https" {
	load_balancer_arn = aws_lb.production.arn
	port              = 443
	protocol          = "HTTPS"
	certificate_arn   = aws_acm_certificate_validation.production.certificate_arn

	default_action {
		type             = "forward"
		target_group_arn = aws_lb_target_group.production-app.arn
	}
}

resource "aws_lb_target_group" "production-app" {
	name        = "production-app"
	target_type = "ip"
	port        = 80
	protocol    = "HTTP"
	vpc_id      = module.vpc.vpc_id
}

resource "aws_route53_record" "production-app" {
	zone_id = aws_route53_zone.production.zone_id
	name    = aws_route53_zone.production.name
	type    = "A"

	alias {
		name    = aws_lb.production.dns_name
		zone_id = aws_lb.production.zone_id
		evaluate_target_health = true
	}
}
