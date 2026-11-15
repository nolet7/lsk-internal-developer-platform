variable "subscription_id" { type=string }
variable "service_name" {
  type=string
  validation {
    condition = can(regex("^[a-z][a-z0-9-]{1,12}$",var.service_name))
    error_message = "Use a short lowercase service identifier."
  }
}
variable "environment" {
  type=string
  validation {
    condition=contains(["dev","staging","prod"],var.environment)
    error_message="Use dev, staging or prod."
  }
}
variable "location" { type=string }
variable "vnet_cidr" { type=string }
variable "image" {
  type=string
  description="Immutable Azure Container Registry image by digest"
  validation {
    condition=can(regex("@sha256:[a-f0-9]{64}$",var.image))
    error_message="Image must use immutable sha256 digest."
  }
}
variable "db_admin_password" {
  type=string
  sensitive=true
  description="Lab-only database administrator credential; prefer identity auth and dedicated app user in production. Stored in Terraform state."
}
variable "key_vault_name" {
  type = string
  description = "Pre-existing secured Key Vault containing app DATABASE_URL"
}
variable "key_vault_resource_group" { type=string }
variable "database_url_secret_id" {
  type=string
  description="Existing Key Vault DATABASE_URL secret ID; pre-created with restricted app DB account and SSL required."
}
variable "oidc_issuer" { type=string }
variable "oidc_audience" { type=string }
variable "oidc_jwks_url" { type=string }
variable "tenant_region_policy" {
  type = map(list(string))
  default = {}
}
variable "pg_sku" {
  type = string
  default = "B_Standard_B1ms"
}
variable "pg_storage_mb" {
  type = number
  default = 32768
}
variable "min_replicas" {
  type = number
  default = 0
}
variable "max_replicas" {
  type = number
  default = 2
}
variable "enable_zone_redundancy" {
  type = bool
  default = false
}
