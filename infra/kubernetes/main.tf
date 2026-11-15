terraform {
  required_version = ">= 1.6"
  backend "s3" {}
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}
provider "aws" { region = var.region }
variable "region" { type = string }
variable "service_name" { type = string }
variable "environment" { type = string }
variable "vpc_cidr" { type = string }
variable "kubernetes_version" { type = string }
variable "cluster_admin_role_arn" { type = string }
variable "node_instance_types" { type = list(string) }
variable "min_nodes" { type = number }
variable "desired_nodes" { type = number }
variable "max_nodes" { type = number }
variable "disk_size_gb" { type = number }
module "kubernetes" {
  source = "../../modules/eks"
  region = var.region
  service_name = var.service_name
  environment = var.environment
  vpc_cidr = var.vpc_cidr
  kubernetes_version = var.kubernetes_version
  cluster_admin_role_arn = var.cluster_admin_role_arn
  node_instance_types = var.node_instance_types
  min_nodes = var.min_nodes
  desired_nodes = var.desired_nodes
  max_nodes = var.max_nodes
  disk_size_gb = var.disk_size_gb
}
output "cluster_name" { value = module.kubernetes.cluster_name }
output "cluster_arn" { value = module.kubernetes.cluster_arn }
output "private_subnet_ids" { value = module.kubernetes.private_subnet_ids }
