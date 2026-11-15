locals {
  prefix = "lsk-idp-${var.environment}"
}
resource "google_project_service" "apis" {
  for_each           = toset(["run.googleapis.com", "sqladmin.googleapis.com", "secretmanager.googleapis.com", "artifactregistry.googleapis.com", "iam.googleapis.com", "aiplatform.googleapis.com"])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}
resource "google_service_account" "runtime" {
  account_id   = "lsk-idp-${var.environment}-runtime"
  display_name = "LSK IDP API runtime"
}
resource "google_artifact_registry_repository" "images" {
  location      = var.region
  repository_id = "lsk-idp-${var.environment}"
  format        = "DOCKER"
  depends_on    = [google_project_service.apis]
}
resource "google_sql_database_instance" "db" {
  name                = "${local.prefix}-postgres"
  database_version    = "POSTGRES_16"
  region              = var.region
  deletion_protection = var.deletion_protection
  settings {
    tier = var.db_tier
    availability_type = var.db_availability_type
    backup_configuration {
      enabled = true
    }
    ip_configuration {
      ipv4_enabled = true
    }
  }
  depends_on = [google_project_service.apis]
}
resource "google_sql_database" "platform" {
  name     = "platform"
  instance = google_sql_database_instance.db.name
}
resource "google_sql_user" "app" {
  name     = "app"
  instance = google_sql_database_instance.db.name
  password = var.db_password
}
resource "google_secret_manager_secret" "database_url" {
  secret_id = "${local.prefix}-database-url"
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}
resource "google_secret_manager_secret_version" "database_url" {
  secret      = google_secret_manager_secret.database_url.id
  secret_data = "postgresql+psycopg://app:${urlencode(var.db_password)}@/platform?host=/cloudsql/${google_sql_database_instance.db.connection_name}"
}
resource "google_secret_manager_secret_iam_member" "runtime_db" {
  secret_id = google_secret_manager_secret.database_url.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}
resource "google_project_iam_member" "runtime_sql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}
resource "google_project_iam_member" "runtime_vertex" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}
resource "google_project_iam_member" "runtime_logging_viewer" {
  project = var.project_id
  role    = "roles/logging.viewer"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}
resource "google_cloud_run_v2_service" "api" {
  name                = local.prefix
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = var.deletion_protection
  template {
    service_account = google_service_account.runtime.email
    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.db.connection_name]
      }
    }
    containers {
      image = var.image
      ports {
        container_port = 8080
      }
      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.database_url.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      env {
        name  = "GOOGLE_CLOUD_LOCATION"
        value = var.region
      }
      env {
        name  = "GOOGLE_GENAI_MODEL"
        value = var.genai_model
      }
      env {
        name  = "LSK_OPS_ALLOWED_SERVICES"
        value = var.ops_allowed_services
      }
      env {
        name  = "LSK_ENFORCE_RESIDENCY"
        value = "true"
      }
      env {
        name  = "LSK_DEPLOYMENT_REGION"
        value = var.region
      }
      env {
        name  = "LSK_TENANT_REGION_POLICY"
        value = jsonencode(var.tenant_region_policy)
      }

      env {
        name  = "OIDC_ISSUER"
        value = var.oidc_issuer
      }
      env {
        name  = "OIDC_AUDIENCE"
        value = var.oidc_audience
      }
      env {
        name  = "OIDC_JWKS_URL"
        value = var.oidc_jwks_url
      }
    }
  }
  depends_on = [
    google_project_service.apis,
    google_project_iam_member.runtime_sql,
    google_project_iam_member.runtime_vertex,
    google_project_iam_member.runtime_logging_viewer,
    google_secret_manager_secret_iam_member.runtime_db,
    google_secret_manager_secret_version.database_url,
  ]
}
# No allUsers Cloud Run invoker IAM binding. Grant only trusted principals.
output "service_uri" {
  value = google_cloud_run_v2_service.api.uri
}
output "artifact_repository" {
  value = google_artifact_registry_repository.images.name
}
output "runtime_service_account" {
  value = google_service_account.runtime.email
}
output "sql_connection" {
  value = google_sql_database_instance.db.connection_name
}
output "db_secret" {
  value = google_secret_manager_secret.database_url.secret_id
}
