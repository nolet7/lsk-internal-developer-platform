terraform {
  required_version = ">= 1.6"
  backend "s3" {}
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}
provider "aws" {
  region = var.region
  default_tags {
    tags = { Organization = "LSK", Service = var.service_name, Environment = var.environment, ManagedBy = "Terraform" }
  }
}
data "aws_availability_zones" "available" { state = "available" }
data "aws_caller_identity" "current" {}
