# Optional VPC per LSK service deployment in a regional GCP project.
resource "google_compute_network" "private" {
  count                   = var.enable_private_sql ? 1 : 0
  name                    = "lsk-idp-${var.environment}-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}
resource "google_compute_subnetwork" "private" {
  count                    = var.enable_private_sql ? 1 : 0
  name                     = "lsk-idp-${var.environment}-subnet"
  region                   = var.region
  ip_cidr_range            = var.private_subnet_cidr
  network                  = google_compute_network.private[0].id
  private_ip_google_access = true
}
resource "google_compute_global_address" "private_service_range" {
  count         = var.enable_private_sql ? 1 : 0
  name          = "lsk-idp-${var.environment}-psa"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.private[0].id
}
resource "google_service_networking_connection" "private_services" {
  count                   = var.enable_private_sql ? 1 : 0
  network                 = google_compute_network.private[0].id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range[0].name]
  depends_on              = [google_project_service.apis]
}
output "private_vpc_name" {
  value = var.enable_private_sql ? google_compute_network.private[0].name : null
}
output "private_subnet_name" {
  value = var.enable_private_sql ? google_compute_subnetwork.private[0].name : null
}
