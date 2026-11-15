terraform {
  required_version = ">= 1.6.0"
  backend "gcs" {}
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}
provider "google" {
  project = var.project_id
  region = var.region
}
variable "project_id" { type = string }
variable "region" { type = string }
variable "service_name" { type = string }
variable "environment" { type = string }
variable "nodes_cidr" { type = string }
variable "pods_cidr" { type = string }
variable "services_cidr" { type = string }
variable "master_cidr" { type = string }
variable "node_zones" { type = list(string) }
variable "machine_type" { type = string }
variable "disk_size_gb" { type = number }
variable "min_nodes_per_zone" { type = number }
variable "max_nodes_per_zone" { type = number }
variable "release_channel" { type = string }
module "kubernetes" {
  source = "../../modules/gke"
  project_id = var.project_id
  region = var.region
  service_name = var.service_name
  environment = var.environment
  nodes_cidr = var.nodes_cidr
  pods_cidr = var.pods_cidr
  services_cidr = var.services_cidr
  master_cidr = var.master_cidr
  node_zones = var.node_zones
  machine_type = var.machine_type
  disk_size_gb = var.disk_size_gb
  min_nodes_per_zone = var.min_nodes_per_zone
  max_nodes_per_zone = var.max_nodes_per_zone
  release_channel = var.release_channel
}
output "cluster_name" { value = module.kubernetes.cluster_name }
output "cluster_location" { value = module.kubernetes.cluster_location }
output "private_endpoint" { value = module.kubernetes.cluster_endpoint_private sensitive = true }
output "network_id" { value = module.kubernetes.network_id }
