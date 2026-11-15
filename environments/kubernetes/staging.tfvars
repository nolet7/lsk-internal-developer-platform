# LSK EKS staging - cluster admin role and service name required at plan time.
environment = "staging"
region = "us-east-1"
vpc_cidr = "10.170.0.0/16"
kubernetes_version = "1.33"
node_instance_types = ["m6i.large"]
min_nodes = 2
desired_nodes = 2
max_nodes = 4
disk_size_gb = 80
