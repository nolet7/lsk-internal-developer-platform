variable "project_id" {
  description = "GCP project where LSK networking lab will be created"
  type        = string
}
variable "region" {
  description = "Region of LSK lab subnet and Cloud NAT"
  type        = string
}
variable "name_prefix" {
  description = "Globally distinguishable short prefix, e.g. lsk-lab"
  type        = string
}
variable "subnet_cidr" {
  description = "Internal subnet CIDR; plan a non-overlapping range"
  type        = string
  validation {
    condition     = can(cidrhost(var.subnet_cidr, 2))
    error_message = "Provide a valid IPv4 CIDR."
  }
}
variable "enable_cloud_nat" {
  description = "Optional paid Cloud NAT for private workloads"
  type        = bool
  default     = false
}
variable "enable_private_services_access" {
  description = "Create Private Service Access connection; may affect deletion/peering cleanup"
  type        = bool
  default     = false
}
variable "service_peering_prefix_length" {
  description = "Prefix length of separately reserved Private Service Access IP range"
  type        = number
  default     = 16
  validation {
    condition     = var.service_peering_prefix_length >= 16 && var.service_peering_prefix_length <= 24
    error_message = "Choose a prefix length between 16 and 24."
  }
}
