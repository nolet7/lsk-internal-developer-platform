variable "region" { type = string }
variable "service_name" {
  type = string
  validation {
    condition = can(regex("^[a-z][a-z0-9-]{1,12}$", var.service_name))
    error_message = "Provide a short DNS-safe service name."
  }
}
variable "environment" {
  type = string
  validation {
    condition = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging or prod."
  }
}
variable "vpc_cidr" { type = string }
variable "kubernetes_version" { type = string }
variable "cluster_admin_role_arn" {
  type = string
  description = "Preapproved IAM principal with gated EKS cluster access."
}
variable "node_instance_types" { type = list(string) }
variable "min_nodes" { type = number }
variable "desired_nodes" { type = number }
variable "max_nodes" { type = number }
variable "disk_size_gb" { type = number }
