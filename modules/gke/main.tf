terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

locals {
  name = "lsk-${var.service_name}-${var.environment}-gke"
  labels = { organization = "lsk", environment = var.environment, application = var.service_name }
}

resource "google_project_service" "services" {
  for_each = toset(["compute.googleapis.com", "container.googleapis.com", "iam.googleapis.com"])
  project = var.project_id
  service = each.key
  disable_on_destroy = false
}

resource "google_compute_network" "cluster" {
  name = "${local.name}-vpc"
  project = var.project_id
  auto_create_subnetworks = false
  depends_on = [google_project_service.services]
}

resource "google_compute_subnetwork" "nodes" {
  name = "${local.name}-subnet"
  project = var.project_id
  region = var.region
  network = google_compute_network.cluster.id
  ip_cidr_range = var.nodes_cidr
  private_ip_google_access = true
  secondary_ip_range {
    range_name = "pods"
    ip_cidr_range = var.pods_cidr
  }
  secondary_ip_range {
    range_name = "services"
    ip_cidr_range = var.services_cidr
  }
}

resource "google_compute_router" "egress" {
  name = "${local.name}-router"
  project = var.project_id
  region = var.region
  network = google_compute_network.cluster.id
}

resource "google_compute_router_nat" "egress" {
  name = "${local.name}-nat"
  project = var.project_id
  region = var.region
  router = google_compute_router.egress.name
  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name = google_compute_subnetwork.nodes.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_service_account" "nodes" {
  project = var.project_id
  account_id = "lsk-${var.service_name}-${var.environment}-gkenodes"
  display_name = "LSK ${var.service_name} ${var.environment} GKE nodes"
}

resource "google_project_iam_member" "node_access" {
  for_each = toset(["roles/logging.logWriter", "roles/monitoring.metricWriter", "roles/artifactregistry.reader"])
  project = var.project_id
  member = "serviceAccount:${google_service_account.nodes.email}"
  role = each.key
}

resource "google_container_cluster" "cluster" {
  project = var.project_id
  name = local.name
  location = var.region
  node_locations = var.node_zones
  network = google_compute_network.cluster.id
  subnetwork = google_compute_subnetwork.nodes.id
  remove_default_node_pool = true
  initial_node_count = 1
  networking_mode = "VPC_NATIVE"
  deletion_protection = var.environment == "prod"
  enable_shielded_nodes = true
  release_channel { channel = var.release_channel }
  workload_identity_config { workload_pool = "${var.project_id}.svc.id.goog" }
  ip_allocation_policy {
    cluster_secondary_range_name = "pods"
    services_secondary_range_name = "services"
  }
  private_cluster_config {
    enable_private_nodes = true
    enable_private_endpoint = true
    master_ipv4_cidr_block = var.master_cidr
  }
  logging_config { enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"] }
  monitoring_config { enable_components = ["SYSTEM_COMPONENTS"] }
  depends_on = [google_project_service.services]
}

resource "google_container_node_pool" "system" {
  project = var.project_id
  name = "${local.name}-system"
  location = var.region
  cluster = google_container_cluster.cluster.name
  node_count = 1
  autoscaling {
    min_node_count = var.min_nodes_per_zone
    max_node_count = var.max_nodes_per_zone
  }
  management {
    auto_repair = true
    auto_upgrade = true
  }
  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type = "pd-balanced"
    image_type = "COS_CONTAINERD"
    service_account = google_service_account.nodes.email
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    labels = local.labels
    shielded_instance_config {
      enable_secure_boot = true
      enable_integrity_monitoring = true
    }
    workload_metadata_config { mode = "GKE_METADATA" }
  }
  depends_on = [google_project_iam_member.node_access, google_compute_router_nat.egress]
}

output "cluster_name" { value = google_container_cluster.cluster.name }
output "cluster_location" { value = google_container_cluster.cluster.location }
output "cluster_endpoint_private" {
  value = google_container_cluster.cluster.private_cluster_config[0].private_endpoint
  sensitive = true
}
output "network_id" { value = google_compute_network.cluster.id }
output "subnet_id" { value = google_compute_subnetwork.nodes.id }
output "workload_identity_pool" { value = "${var.project_id}.svc.id.goog" }
