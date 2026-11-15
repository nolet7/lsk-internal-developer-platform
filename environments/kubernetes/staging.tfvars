# GKE staging, sample region only; project_id and service_name are supplied securely at plan time.
environment = "staging"
region = "us-central1"
nodes_cidr = "10.120.0.0/20"
pods_cidr = "10.122.0.0/16"
services_cidr = "10.123.0.0/20"
master_cidr = "172.20.1.0/28"
node_zones = ["us-central1-a","us-central1-b"]
machine_type = "e2-standard-4"
disk_size_gb = 80
min_nodes_per_zone = 1
max_nodes_per_zone = 3
release_channel = "REGULAR"
