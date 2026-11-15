# Azure AKS prod: supply subscription_id, service_name and approved admin_group_object_ids at plan time.
environment = "prod"
location = "eastus2"
vnet_cidr = "10.240.0.0/16"
nodes_subnet_cidr = "10.240.0.0/20"
pods_cidr = "10.246.0.0/16"
services_cidr = "10.250.0.0/16"
dns_service_ip = "10.250.0.10"
node_vm_size = "Standard_D4s_v5"
disk_size_gb = 100
min_nodes = 2
desired_nodes = 3
max_nodes = 8
zones = ["1","2","3"]
