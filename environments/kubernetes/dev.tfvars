# GKE dev, sample region only; project_id and service_name are supplied securely at plan time.
environment = "dev"
region = "us-central1"
nodes_cidr = "10.110.0.0/20"
pods_cidr = "10.112.0.0/16"
services_cidr = "10.113.0.0/20"
master_cidr = "172.20.0.0/28"
node_zones = ["us-central1-a"]
machine_type = "e2-standard-2"
disk_size_gb = 50
min_nodes_per_zone = 1
max_nodes_per_zone = 2
release_channel = "REGULAR"
