resource "google_project_service" "compute" {
  project            = var.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}
resource "google_project_service" "networking" {
  project            = var.project_id
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}
resource "google_compute_network" "main" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  depends_on              = [google_project_service.compute]
}
resource "google_compute_subnetwork" "private" {
  name                     = "${var.name_prefix}-private-${var.region}"
  ip_cidr_range            = var.subnet_cidr
  region                   = var.region
  network                  = google_compute_network.main.id
  private_ip_google_access = true
}
resource "google_compute_router" "nat" {
  count   = var.enable_cloud_nat ? 1 : 0
  name    = "${var.name_prefix}-router"
  network = google_compute_network.main.id
  region  = var.region
}
resource "google_compute_router_nat" "nat" {
  count                              = var.enable_cloud_nat ? 1 : 0
  name                               = "${var.name_prefix}-cloud-nat"
  router                             = google_compute_router.nat[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.private.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}
resource "google_compute_global_address" "private_service_range" {
  count         = var.enable_private_services_access ? 1 : 0
  name          = "${var.name_prefix}-private-services-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.service_peering_prefix_length
  network       = google_compute_network.main.id
}
resource "google_service_networking_connection" "private_services" {
  count                   = var.enable_private_services_access ? 1 : 0
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range[0].name]
  depends_on              = [google_project_service.networking]
}
output "network_id" {
  value = google_compute_network.main.id
}
output "private_subnet_id" {
  value = google_compute_subnetwork.private.id
}
output "nat_enabled" {
  value = var.enable_cloud_nat
}
output "private_services_access_enabled" {
  value = var.enable_private_services_access
}
