variable "project_id" { type = string }
variable "region" { type = string }
variable "service_name" {
  type = string
  validation {
    condition = can(regex("^[a-z][a-z0-9-]{1,12}$", var.service_name))
    error_message = "Use a short lowercase DNS-safe service name."
  }
}
variable "environment" {
  type = string
  validation {
    condition = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Use dev, staging, or prod."
  }
}
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
