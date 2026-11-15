# Azure AKS staging: supply subscription_id, service_name and approved admin_group_object_ids at plan time.
environment = "staging"
location = "eastus2"
vnet_cidr = "10.220.0.0/16"
nodes_subnet_cidr = "10.220.0.0/20"
pods_cidr = "10.245.0.0/16"
services_cidr = "10.230.0.0/16"
dns_service_ip = "10.230.0.10"
node_vm_size = "Standard_D4s_v5"
disk_size_gb = 80
min_nodes = 2
desired_nodes = 2
max_nodes = 4
zones = ["1","2"]
