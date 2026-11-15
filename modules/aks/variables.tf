variable "location" { type = string }
variable "service_name" {
  type = string
  validation {
    condition = can(regex("^[a-z][a-z0-9-]{1,12}$", var.service_name))
    error_message = "Service name must be short lowercase alphanumeric/hyphen."
  }
}
variable "environment" {
  type = string
  validation {
    condition = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Use dev, staging or prod."
  }
}
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
variable "admin_group_object_ids" {
  type = list(string)
  description = "Authorized Entra ID group GUIDs for the AKS administrative boundary."
  validation {
    condition = length(var.admin_group_object_ids) > 0
    error_message = "At least one approved Entra administrator group is required."
  }
}
