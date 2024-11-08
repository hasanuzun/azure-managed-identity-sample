locals {
  tags = {
    created-by = "terraform"
  }
}


data "azurerm_client_config" "current" {
}

data "azuread_user" "current" {
  object_id = data.azurerm_client_config.current.object_id
}

data "azurerm_subscription" "current" {}

resource "random_id" "rg-name" {
  byte_length = 5
  prefix      = var.resource_group_name
}


resource "azurerm_resource_group" "rg" {
  name     = random_id.rg-name.dec
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "${azurerm_resource_group.rg.name}-law"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_user_assigned_identity" "mi" {
  name                = "${azurerm_resource_group.rg.name}-mi"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = local.tags
}


resource "azurerm_virtual_network" "vnet" {
  name                = "${azurerm_resource_group.rg.name}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/12"]
  tags                = local.tags
}

resource "azurerm_subnet" "pg-subnet" {
  name                 = "pg-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}
resource "azurerm_subnet" "cae-subnet" {
  name                 = "cae-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.0.0/21"]
  delegation {
    name = "delegation"
    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action"
      ]
    }
  }
}

resource "azurerm_container_app_environment" "app-env" {
  name                               = "${azurerm_resource_group.rg.name}-cae"
  location                           = azurerm_resource_group.rg.location
  resource_group_name                = azurerm_resource_group.rg.name
  log_analytics_workspace_id         = azurerm_log_analytics_workspace.law.id
  infrastructure_subnet_id           = azurerm_subnet.cae-subnet.id
  infrastructure_resource_group_name = "${azurerm_resource_group.rg.name}-infra"
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
  tags = local.tags
}
