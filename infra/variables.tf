variable "project_id" {
  type = string
}
variable "region" {
  type    = string
  default = "us-central1"
}
variable "environment" {
  type    = string
  default = "lab"
}
variable "image" {
  type        = string
  description = "Immutable Artifact Registry image (sha256 digest)"
  validation {
    condition     = can(regex("@sha256:[a-f0-9]{64}$", var.image))
    error_message = "Use an immutable sha256 image digest, not a mutable tag."
  }
}
variable "db_password" {
  type      = string
  sensitive = true
}
variable "oidc_issuer" {
  type = string
}
variable "oidc_audience" {
  type = string
}
variable "oidc_jwks_url" {
  type = string
}
variable "deletion_protection" {
  type    = bool
  default = true
}

variable "genai_model" {
  type        = string
  description = "Explicit approved Vertex Gemini model ID"
}

variable "ops_allowed_services" {
  type        = string
  default     = ""
  description = "Comma-separated allowlist for privileged Cloud Run log triage. Keep empty to disable."
}

variable "tenant_region_policy" {
  type        = map(list(string))
  description = "Signed JWT tenant_id -> allowed deployment regions. Empty map denies every tenant."
  default     = {}
}
variable "db_tier" {
  type        = string
  description = "Cloud SQL instance tier: choose an HA-capable size for production."
  default     = "db-f1-micro"
}
variable "db_availability_type" {
  type    = string
  default = "ZONAL"
  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.db_availability_type)
    error_message = "Use ZONAL or REGIONAL."
  }
}
