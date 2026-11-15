# LSK EKS prod - cluster admin role and service name required at plan time.
environment = "prod"
region = "us-east-1"
vpc_cidr = "10.180.0.0/16"
kubernetes_version = "1.33"
node_instance_types = ["m6i.xlarge"]
min_nodes = 2
desired_nodes = 3
max_nodes = 8
disk_size_gb = 100
