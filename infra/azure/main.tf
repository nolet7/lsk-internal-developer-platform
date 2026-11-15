data "azurerm_client_config" "current" {}
data "azurerm_key_vault" "app" {
  name = var.key_vault_name
  resource_group_name = var.key_vault_resource_group
}
locals {
  name="lsk-${var.service_name}-${var.environment}"
  prod=var.environment=="prod"
  tags={organization="LSK",service=var.service_name,environment=var.environment}
}
resource "azurerm_resource_group" "app" {
  name="${local.name}-rg"
  location=var.location
  tags=local.tags
}
resource "azurerm_virtual_network" "main" {
  name="${local.name}-vnet"
  resource_group_name=azurerm_resource_group.app.name
  location=azurerm_resource_group.app.location
  address_space=[var.vnet_cidr]
  tags=local.tags
}
resource "azurerm_subnet" "apps" {
  name="${local.name}-aca-subnet"
  resource_group_name=azurerm_resource_group.app.name
  virtual_network_name=azurerm_virtual_network.main.name
  address_prefixes=[cidrsubnet(var.vnet_cidr,3,0)]
  delegation {
    name="container-apps"
    service_delegation {
      name="Microsoft.App/environments"
      actions=["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}
resource "azurerm_subnet" "database" {
  name="${local.name}-db-subnet"
  resource_group_name=azurerm_resource_group.app.name
  virtual_network_name=azurerm_virtual_network.main.name
  address_prefixes=[cidrsubnet(var.vnet_cidr,4,2)]
  delegation {
    name="postgres"
    service_delegation {
      name="Microsoft.DBforPostgreSQL/flexibleServers"
      actions=["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}
resource "azurerm_private_dns_zone" "db" {
  name="${local.name}.private.postgres.database.azure.com"
  resource_group_name=azurerm_resource_group.app.name
}
resource "azurerm_private_dns_zone_virtual_network_link" "db" {
  name="${local.name}-postgres-link"
  resource_group_name=azurerm_resource_group.app.name
  private_dns_zone_name=azurerm_private_dns_zone.db.name
  virtual_network_id=azurerm_virtual_network.main.id
  registration_enabled=false
}
resource "azurerm_postgresql_flexible_server" "db" {
  name="${local.name}-postgres"
  resource_group_name=azurerm_resource_group.app.name
  location=azurerm_resource_group.app.location
  version="16"
  delegated_subnet_id=azurerm_subnet.database.id
  private_dns_zone_id=azurerm_private_dns_zone.db.id
  public_network_access_enabled=false
  administrator_login="platformadmin"
  administrator_password=var.db_admin_password
  storage_mb=var.pg_storage_mb
  sku_name=var.pg_sku
  backup_retention_days=local.prod ? 14 : 7
  geo_redundant_backup_enabled=false
  dynamic "high_availability" {
    for_each=var.enable_zone_redundancy ? [1] : []
    content { mode="ZoneRedundant" }
  }
  lifecycle {
    precondition {
      condition=!local.prod || (
        var.enable_zone_redundancy && var.min_replicas >= 2 &&
        var.pg_sku != "B_Standard_B1ms"
      )
      error_message="Production requires PostgreSQL zone redundancy, at least two app replicas and a non-burstable database tier."
    }
  }
  depends_on=[azurerm_private_dns_zone_virtual_network_link.db]
  tags=local.tags
}
resource "azurerm_postgresql_flexible_server_database" "app" {
  name="platform"
  server_id=azurerm_postgresql_flexible_server.db.id
  charset="UTF8"
  collation="en_US.utf8"
}
resource "azurerm_container_registry" "app" {
  name=replace("${var.service_name}${var.environment}${substr(var.subscription_id,0,6)}lsk","-","")
  resource_group_name=azurerm_resource_group.app.name
  location=azurerm_resource_group.app.location
  sku="Premium"
  admin_enabled=false
  tags=local.tags
}
resource "azurerm_user_assigned_identity" "runtime" {
  name="${local.name}-runtime"
  resource_group_name=azurerm_resource_group.app.name
  location=azurerm_resource_group.app.location
  tags=local.tags
}
resource "azurerm_role_assignment" "registry_pull" {
  scope=azurerm_container_registry.app.id
  role_definition_name="AcrPull"
  principal_id=azurerm_user_assigned_identity.runtime.principal_id
}
resource "azurerm_role_assignment" "secret_reader" {
  scope=data.azurerm_key_vault.app.id
  role_definition_name="Key Vault Secrets User"
  principal_id=azurerm_user_assigned_identity.runtime.principal_id
}
resource "azurerm_log_analytics_workspace" "app" {
  name="${local.name}-logs"
  resource_group_name=azurerm_resource_group.app.name
  location=azurerm_resource_group.app.location
  sku="PerGB2018"
  retention_in_days=local.prod ? 90 : 30
  tags=local.tags
}
resource "azurerm_container_app_environment" "app" {
  name="${local.name}-environment"
  resource_group_name=azurerm_resource_group.app.name
  location=azurerm_resource_group.app.location
  infrastructure_subnet_id=azurerm_subnet.apps.id
  internal_load_balancer_enabled=true
  zone_redundancy_enabled=var.enable_zone_redundancy
  log_analytics_workspace_id=azurerm_log_analytics_workspace.app.id
  tags=local.tags
}
resource "azurerm_container_app" "api" {
  name=local.name
  resource_group_name=azurerm_resource_group.app.name
  container_app_environment_id=azurerm_container_app_environment.app.id
  revision_mode="Single"
  identity {
    type="UserAssigned"
    identity_ids=[azurerm_user_assigned_identity.runtime.id]
  }
  registry {
    server=azurerm_container_registry.app.login_server
    identity=azurerm_user_assigned_identity.runtime.id
  }
  secret {
    name="database-url"
    key_vault_secret_id=var.database_url_secret_id
    identity=azurerm_user_assigned_identity.runtime.id
  }
  template {
    min_replicas=var.min_replicas
    max_replicas=var.max_replicas
    container {
      name="api"
      image=var.image
      cpu=0.5
      memory="1Gi"
      env { name="DATABASE_URL" secret_name="database-url" }
      env { name="OIDC_ISSUER" value=var.oidc_issuer }
      env { name="OIDC_AUDIENCE" value=var.oidc_audience }
      env { name="OIDC_JWKS_URL" value=var.oidc_jwks_url }
      env { name="LSK_ENFORCE_RESIDENCY" value="true" }
      env { name="LSK_DEPLOYMENT_REGION" value=var.location }
      env { name="LSK_TENANT_REGION_POLICY" value=jsonencode(var.tenant_region_policy) }
    }
  }
  ingress {
    external_enabled=true
    target_port=8080
    transport="http"
    allow_insecure_connections=false
    traffic_weight {
      percentage=100
      latest_revision=true
    }
  }
  depends_on=[azurerm_role_assignment.registry_pull,azurerm_role_assignment.secret_reader,
              azurerm_postgresql_flexible_server_database.app]
  tags=local.tags
}
output "container_app_fqdn" { value=azurerm_container_app.api.ingress[0].fqdn }
output "acr_login_server" { value=azurerm_container_registry.app.login_server }
output "resource_group" { value=azurerm_resource_group.app.name }
output "postgres_host" { value=azurerm_postgresql_flexible_server.db.fqdn }
