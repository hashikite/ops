provider "aws" {
	version = "~> 2.67"
	region = "us-east-1"
}

data "aws_region" "primary" {
}
  
data "aws_availability_zones" "primary" {
}
