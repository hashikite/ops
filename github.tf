data "aws_ssm_parameter" "github-token" {
	name = "/ops/terraform/GITHUB_TOKEN"
}

provider "github" {
	version      = "~> 2.8"
	token        = data.aws_ssm_parameter.github-token.value
	organization = "hashikite"
}
