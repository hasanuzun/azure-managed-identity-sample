resource "azuread_application_registration" "aad-app" {
  display_name = "${azurerm_resource_group.rg.name}-sso"
}

resource "azuread_application_password" "aad-app-secret" {
  application_id = azuread_application_registration.aad-app.id
}