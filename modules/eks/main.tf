terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}
locals {
  name = "lsk-${var.service_name}-${var.environment}-eks"
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
  production = var.environment == "prod"
}
resource "aws_vpc" "cluster" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = { Name = "${local.name}-vpc" }
}
resource "aws_internet_gateway" "egress" {
  vpc_id = aws_vpc.cluster.id
}
resource "aws_subnet" "public" {
  count = 2
  vpc_id = aws_vpc.cluster.id
  availability_zone = local.azs[count.index]
  cidr_block = cidrsubnet(var.vpc_cidr, 4, count.index)
  map_public_ip_on_launch = false
  tags = {
    Name = "${local.name}-public-${count.index}"
    "kubernetes.io/role/elb" = "1"
  }
}
resource "aws_subnet" "private" {
  count = 2
  vpc_id = aws_vpc.cluster.id
  availability_zone = local.azs[count.index]
  cidr_block = cidrsubnet(var.vpc_cidr, 4, count.index + 2)
  tags = {
    Name = "${local.name}-private-${count.index}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.cluster.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.egress.id
  }
}
resource "aws_route_table_association" "public" {
  count = 2
  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
resource "aws_eip" "nat" {
  count = local.production ? 2 : 1
  domain = "vpc"
  depends_on = [aws_internet_gateway.egress]
}
resource "aws_nat_gateway" "nat" {
  count = local.production ? 2 : 1
  subnet_id = aws_subnet.public[count.index].id
  allocation_id = aws_eip.nat[count.index].id
}
resource "aws_route_table" "private" {
  count = 2
  vpc_id = aws_vpc.cluster.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[local.production ? count.index : 0].id
  }
}
resource "aws_route_table_association" "private" {
  count = 2
  subnet_id = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "cluster" {
  name = "${local.name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
}
resource "aws_iam_role_policy_attachment" "cluster" {
  role = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "nodes" {
  name = "${local.name}-nodes-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
}
resource "aws_iam_role_policy_attachment" "nodes" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  ])
  role = aws_iam_role.nodes.name
  policy_arn = each.value
}
resource "aws_cloudwatch_log_group" "control_plane" {
  name = "/aws/eks/${local.name}/cluster"
  retention_in_days = local.production ? 90 : 14
}
resource "aws_eks_cluster" "cluster" {
  name = local.name
  version = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn
  access_config {
    authentication_mode = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }
  vpc_config {
    subnet_ids = aws_subnet.private[*].id
    endpoint_private_access = true
    endpoint_public_access = false
  }
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  depends_on = [aws_iam_role_policy_attachment.cluster, aws_cloudwatch_log_group.control_plane]
}
resource "aws_eks_access_entry" "platform_admin" {
  cluster_name = aws_eks_cluster.cluster.name
  principal_arn = var.cluster_admin_role_arn
  type = "STANDARD"
}
resource "aws_eks_access_policy_association" "platform_admin" {
  cluster_name = aws_eks_cluster.cluster.name
  principal_arn = aws_eks_access_entry.platform_admin.principal_arn
  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
}
resource "aws_eks_node_group" "system" {
  cluster_name = aws_eks_cluster.cluster.name
  node_group_name = "${local.name}-system"
  node_role_arn = aws_iam_role.nodes.arn
  subnet_ids = aws_subnet.private[*].id
  instance_types = var.node_instance_types
  capacity_type = "ON_DEMAND"
  disk_size = var.disk_size_gb
  ami_type = "AL2023_x86_64_STANDARD"
  scaling_config {
    min_size = var.min_nodes
    desired_size = var.desired_nodes
    max_size = var.max_nodes
  }
  update_config {
    max_unavailable = 1
  }
  lifecycle {
    precondition {
      condition = !local.production || (var.desired_nodes >= 3 && var.min_nodes >= 2 && var.max_nodes >= 3)
      error_message = "LSK production EKS must start with >=3 workers and permit at least two healthy nodes."
    }
  }
  depends_on = [aws_iam_role_policy_attachment.nodes, aws_route_table_association.private]
}
output "cluster_name" { value = aws_eks_cluster.cluster.name }
output "cluster_arn" { value = aws_eks_cluster.cluster.arn }
output "region_vpc_id" { value = aws_vpc.cluster.id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
output "node_group_name" { value = aws_eks_node_group.system.node_group_name }
