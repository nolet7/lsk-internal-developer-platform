# GKE prod, sample region only; project_id and service_name are supplied securely at plan time.
environment = "prod"
region = "us-central1"
nodes_cidr = "10.130.0.0/20"
pods_cidr = "10.132.0.0/16"
services_cidr = "10.133.0.0/20"
master_cidr = "172.20.2.0/28"
node_zones = ["us-central1-a","us-central1-b","us-central1-c"]
machine_type = "e2-standard-4"
disk_size_gb = 100
min_nodes_per_zone = 2
max_nodes_per_zone = 5
release_channel = "REGULAR"
