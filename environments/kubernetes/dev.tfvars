# LSK EKS dev - cluster admin role and service name required at plan time.
environment = "dev"
region = "us-east-1"
vpc_cidr = "10.160.0.0/16"
kubernetes_version = "1.33"
node_instance_types = ["t3.large"]
min_nodes = 1
desired_nodes = 2
max_nodes = 3
disk_size_gb = 50
