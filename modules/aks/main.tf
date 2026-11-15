terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

locals {
  name = "lsk-${var.service_name}-${var.environment}-aks"
  production = var.environment == "prod"
  tags = { organization = "lsk", environment = var.environment, service = var.service_name, managed_by = "terraform" }
}
resource "azurerm_resource_group" "cluster" {
  name = "${local.name}-rg"
  location = var.location
  tags = local.tags
}
resource "azurerm_virtual_network" "cluster" {
  name = "${local.name}-vnet"
  location = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  address_space = [var.vnet_cidr]
  tags = local.tags
}
resource "azurerm_subnet" "nodes" {
  name = "${local.name}-nodes"
  resource_group_name = azurerm_resource_group.cluster.name
  virtual_network_name = azurerm_virtual_network.cluster.name
  address_prefixes = [var.nodes_subnet_cidr]
}
resource "azurerm_public_ip" "nat" {
  name = "${local.name}-nat-ip"
  location = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  allocation_method = "Static"
  sku = "Standard"
  tags = local.tags
}
resource "azurerm_nat_gateway" "nodes" {
  name = "${local.name}-nat"
  location = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  sku_name = "Standard"
  tags = local.tags
}
resource "azurerm_nat_gateway_public_ip_association" "nat" {
  nat_gateway_id = azurerm_nat_gateway.nodes.id
  public_ip_address_id = azurerm_public_ip.nat.id
}
resource "azurerm_subnet_nat_gateway_association" "nodes" {
  subnet_id = azurerm_subnet.nodes.id
  nat_gateway_id = azurerm_nat_gateway.nodes.id
}
resource "azurerm_user_assigned_identity" "cluster" {
  name = "${local.name}-identity"
  location = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  tags = local.tags
}
resource "azurerm_role_assignment" "network" {
  scope = azurerm_subnet.nodes.id
  role_definition_name = "Network Contributor"
  principal_id = azurerm_user_assigned_identity.cluster.principal_id
}
resource "azurerm_log_analytics_workspace" "cluster" {
  name = "${local.name}-logs"
  location = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  sku = "PerGB2018"
  retention_in_days = local.production ? 90 : 30
  tags = local.tags
}
resource "azurerm_kubernetes_cluster" "cluster" {
  name = local.name
  location = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  dns_prefix = "${var.service_name}-${var.environment}-k8s"
  sku_tier = local.production ? "Standard" : "Free"
  private_cluster_enabled = true
  private_dns_zone_id = "System"
  local_account_disabled = true
  role_based_access_control_enabled = true
  azure_policy_enabled = true
  oidc_issuer_enabled = true
  workload_identity_enabled = true
  automatic_upgrade_channel = "patch"
  default_node_pool {
    name = "system"
    node_count = var.desired_nodes
    min_count = var.min_nodes
    max_count = var.max_nodes
    auto_scaling_enabled = true
    vm_size = var.node_vm_size
    vnet_subnet_id = azurerm_subnet.nodes.id
    os_disk_size_gb = var.disk_size_gb
    zones = var.zones
    max_pods = 30
  }
  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.cluster.id]
  }
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    admin_group_object_ids = var.admin_group_object_ids
  }
  network_profile {
    network_plugin = "azure"
    network_plugin_mode = "overlay"
    network_data_plane = "cilium"
    network_policy = "cilium"
    load_balancer_sku = "standard"
    outbound_type = "userAssignedNATGateway"
    pod_cidr = var.pods_cidr
    service_cidr = var.services_cidr
    dns_service_ip = var.dns_service_ip
  }
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.cluster.id
  }
  tags = local.tags
  lifecycle {
    precondition {
      condition = !local.production || (
        var.min_nodes >= 2 &&
        var.desired_nodes >= 3 &&
        length(var.zones) >= 2
      )
      error_message = "LSK production AKS needs 3 initial nodes and at least two zones."
    }
  }
  depends_on = [azurerm_role_assignment.network, azurerm_subnet_nat_gateway_association.nodes]
}
output "cluster_name" { value = azurerm_kubernetes_cluster.cluster.name }
output "resource_group_name" { value = azurerm_resource_group.cluster.name }
output "node_subnet_id" { value = azurerm_subnet.nodes.id }
output "oidc_issuer_url" { value = azurerm_kubernetes_cluster.cluster.oidc_issuer_url }
output "log_analytics_workspace_id" { value = azurerm_log_analytics_workspace.cluster.id }
