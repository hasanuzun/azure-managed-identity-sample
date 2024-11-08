
resource "random_id" "kv-name" {
  byte_length = 5
  prefix      = "${replace(var.resource_group_name, "-", "")}kv"
}

resource "azurerm_key_vault" "kv" {
  name                        = random_id.kv-name.hex
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"
}


resource "azurerm_key_vault_access_policy" "mi-kv-access" {
  key_vault_id       = azurerm_key_vault.kv.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azurerm_user_assigned_identity.mi.principal_id
  secret_permissions = ["Get", "List"]
}

resource "azurerm_key_vault_access_policy" "usr-kv-access" {
  key_vault_id        = azurerm_key_vault.kv.id
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = data.azurerm_client_config.current.object_id
  key_permissions     = ["Get", "List"]
  secret_permissions  = ["Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"]
  storage_permissions = ["Get", "List"]
}





