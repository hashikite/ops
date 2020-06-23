terraform {
  required_version = ">= 0.12"
  backend "s3" {
    region = "us-east-1"
    bucket = "ops.production.hashikite.net"
    key    = "terraform/terraform.tfstate"
  }
}

