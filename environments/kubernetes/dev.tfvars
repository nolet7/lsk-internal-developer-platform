# Azure AKS dev: supply subscription_id, service_name and approved admin_group_object_ids at plan time.
environment = "dev"
location = "eastus2"
vnet_cidr = "10.200.0.0/16"
nodes_subnet_cidr = "10.200.0.0/20"
pods_cidr = "10.244.0.0/16"
services_cidr = "10.210.0.0/16"
dns_service_ip = "10.210.0.10"
node_vm_size = "Standard_D2s_v5"
disk_size_gb = 64
min_nodes = 1
desired_nodes = 1
max_nodes = 2
zones = ["1"]
