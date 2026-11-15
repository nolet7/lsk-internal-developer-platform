variable "service_name" {
  type = string
  description = "Short service identifier, e.g. billing. Controls resource names."
  validation {
    condition = can(regex("^[a-z][a-z0-9-]{1,15}$", var.service_name))
    error_message = "Use a lowercase, short service name."
  }
}
variable "environment" {
  type = string
  validation {
    condition = contains(["dev","staging","prod"],var.environment)
    error_message = "Choose dev, staging or prod."
  }
}
variable "region" { type = string }
variable "vpc_cidr" { type = string }
variable "image" {
  type = string
  description = "Full ECR URI pinned by immutable sha256 digest"
  validation {
    condition = can(regex("@sha256:[a-f0-9]{64}$",var.image))
    error_message = "Container image must be pinned by sha256 digest."
  }
}
variable "certificate_arn" {
  type = string
  description = "Validated ACM certificate matching the internal DNS name."
}
variable "allowed_ingress_cidrs" {
  type = list(string)
  description = "Corporate CIDRs that may reach the internal HTTPS ALB."
  default = []
}
variable "db_password" {
  type = string
  sensitive = true
  description = "Temporary lab password; a production release should use managed rotation and eliminate password material from Terraform state."
}
variable "oidc_issuer" { type = string }
variable "oidc_audience" { type = string }
variable "oidc_jwks_url" { type = string }
variable "tenant_region_policy" {
  type = map(list(string))
  default = {}
}
variable "desired_count" {
  type = number
  default = 1
}
variable "db_instance_class" {
  type = string
  default = "db.t4g.micro"
}
variable "db_deletion_protection" {
  type = bool
  default = false
}
variable "db_backup_retention_days" {
  type = number
  default = 7
}
variable "ecs_cpu" {
  type = number
  default = 512
}
variable "ecs_memory" {
  type = number
  default = 1024
}

variable "bedrock_model_id" { type = string }
variable "bedrock_model_arn" { type = string }
