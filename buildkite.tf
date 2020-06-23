data "aws_ssm_parameter" "buildkite-api-token" {
	name = "/ops/terraform/BUILDKITE_API_TOKEN"
}

# https://github.com/sj26/terraform-provider-buildkite
provider "buildkite" {
	version      = "~> 0.1.1"
	api_token    = data.aws_ssm_parameter.buildkite-api-token.value
	organization = "hashikite"
}
