
locals {
  connString = "Server=${azurerm_postgresql_flexible_server.pg.fqdn};Database=${azurerm_postgresql_flexible_server_database.pg-db.name};Port=5432;User Id=${azurerm_user_assigned_identity.mi.name};Password=;Ssl Mode=Require;"
}

resource "random_id" "pg-name" {
  byte_length = 3
  prefix      = "${replace(var.resource_group_name, "-", "")}pg"
}

resource "azurerm_private_dns_zone" "pg-dns-zone" {
  count               = var.postgres.public_network_access_enabled ? 0 : 1
  name                = "mi-example.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "pg-link" {
  count                 = var.postgres.public_network_access_enabled ? 0 : 1
  name                  = random_id.pg-name.dec
  private_dns_zone_name = azurerm_private_dns_zone.pg-dns-zone[0].name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  resource_group_name   = azurerm_resource_group.rg.name
  depends_on            = [azurerm_subnet.pg-subnet]
}

resource "azurerm_postgresql_flexible_server" "pg" {
  name                          = random_id.pg-name.dec
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  version                       = "16"
  delegated_subnet_id           = var.postgres.public_network_access_enabled ? null : azurerm_subnet.pg-subnet.id
  private_dns_zone_id           = var.postgres.public_network_access_enabled ? null : azurerm_private_dns_zone.pg-dns-zone[0].id
  public_network_access_enabled = var.postgres.public_network_access_enabled
  sku_name                      = var.postgres.sku_name
  auto_grow_enabled             = true
  tags                          = local.tags

  storage_mb   = 32768
  storage_tier = "P4"

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = false
    tenant_id                     = data.azurerm_client_config.current.tenant_id
  }

  lifecycle {
    ignore_changes = [
      zone,
      high_availability.0.standby_availability_zone
    ]
  }

  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.pg-link]
}

resource "azurerm_postgresql_flexible_server_database" "pg-db" {
  name      = "sample"
  server_id = azurerm_postgresql_flexible_server.pg.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "pg-admin-mi" {
  server_name         = azurerm_postgresql_flexible_server.pg.name
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = azurerm_user_assigned_identity.mi.principal_id
  principal_name      = azurerm_user_assigned_identity.mi.name
  principal_type      = "ServicePrincipal"
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "pg-admin" {
  server_name         = azurerm_postgresql_flexible_server.pg.name
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = data.azuread_user.current.object_id
  principal_name      = data.azuread_user.current.user_principal_name
  principal_type      = "User"
}

resource "azurerm_key_vault_secret" "pg-conn-string" {
  name         = "PostgresConnectionString"
  value        = local.connString
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_key_vault_access_policy.usr-kv-access]
}

output "pgServerFqdn" {
  value     = azurerm_postgresql_flexible_server.pg.fqdn
  sensitive = false
}

