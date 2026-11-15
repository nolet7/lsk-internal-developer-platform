resource "azurerm_role_assignment" "azure_openai_user" {
  scope = var.azure_ai_resource_id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id = azurerm_user_assigned_identity.runtime.principal_id
}
resource "azurerm_role_assignment" "monitor_reader" {
  scope = azurerm_log_analytics_workspace.app.id
  role_definition_name = "Log Analytics Reader"
  principal_id = azurerm_user_assigned_identity.runtime.principal_id
}
