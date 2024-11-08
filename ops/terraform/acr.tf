resource "azurerm_container_registry" "acr" {
  name                = "${replace(azurerm_resource_group.rg.name, "-", "")}acr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  admin_enabled       = false
  sku                 = "Basic"
  tags                = local.tags
}

resource "azurerm_role_assignment" "acr-mi-role" {
  principal_id                     = azurerm_user_assigned_identity.mi.principal_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "acr-usr-role" {
  principal_id                     = data.azurerm_client_config.current.object_id
  role_definition_name             = "Contributor"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
  principal_type                   = "User"
}
