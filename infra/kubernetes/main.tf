terraform {
  required_version = ">= 1.6"
  backend "azurerm" {}
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
variable "subscription_id" { type = string }
variable "location" { type = string }
variable "service_name" { type = string }
variable "environment" { type = string }
variable "vnet_cidr" { type = string }
variable "nodes_subnet_cidr" { type = string }
variable "pods_cidr" { type = string }
variable "services_cidr" { type = string }
variable "dns_service_ip" { type = string }
variable "node_vm_size" { type = string }
variable "disk_size_gb" { type = number }
variable "min_nodes" { type = number }
variable "desired_nodes" { type = number }
variable "max_nodes" { type = number }
variable "zones" { type = list(string) }
variable "admin_group_object_ids" { type = list(string) }
module "kubernetes" {
  source = "../../modules/aks"
  location = var.location
  service_name = var.service_name
  environment = var.environment
  vnet_cidr = var.vnet_cidr
  nodes_subnet_cidr = var.nodes_subnet_cidr
  pods_cidr = var.pods_cidr
  services_cidr = var.services_cidr
  dns_service_ip = var.dns_service_ip
  node_vm_size = var.node_vm_size
  disk_size_gb = var.disk_size_gb
  min_nodes = var.min_nodes
  desired_nodes = var.desired_nodes
  max_nodes = var.max_nodes
  zones = var.zones
  admin_group_object_ids = var.admin_group_object_ids
}
output "cluster_name" { value = module.kubernetes.cluster_name }
output "resource_group_name" { value = module.kubernetes.resource_group_name }
output "cluster_oidc_issuer" { value = module.kubernetes.oidc_issuer_url }
