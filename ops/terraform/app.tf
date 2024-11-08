# https://www.pgadmin.org/docs/pgadmin4/latest/container_deployment.html

locals {
  api_target_port          = 8080
  image_tag                = formatdate("YYYYMMDDhhmmss", timestamp())
  api_docker_image         = "${var.sampleApi.image}:${local.image_tag}"
  api_docker_image_acr_tag = "${azurerm_container_registry.acr.login_server}/${local.api_docker_image}"
}


resource "azurerm_container_app" "app" {
  name                         = "${azurerm_resource_group.rg.name}-app"
  container_app_environment_id = azurerm_container_app_environment.app-env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"
  tags                         = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.mi.id]
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.mi.id
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = local.api_target_port
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    container {
      name   = "sample-app"
      image  = local.api_docker_image_acr_tag
      cpu    = var.sampleApi.cpu
      memory = var.sampleApi.memory

      env {
        name  = "KeyVaultName"
        value = azurerm_key_vault.kv.name
      }

      env {
        name  = "ManagedIdentityClientId"
        value = azurerm_user_assigned_identity.mi.client_id
      }

      env {
        name  = "TZ"
        value = "Europe/Berlin"
      }
    }
  }

  depends_on = [
    null_resource.push-api-image, azurerm_postgresql_flexible_server.pg,
    azurerm_key_vault_access_policy.mi-kv-access
  ]
}

resource "null_resource" "build-api-image" {
  triggers = {
    tagName = local.image_tag
  }
  provisioner "local-exec" {
    working_dir = "../../src/"
    command     = "docker buildx build -t ${local.api_docker_image_acr_tag} --platform linux/amd64 -f SampleApi/Dockerfile ."
  }
}

resource "null_resource" "push-api-image" {
  triggers = {
    tagName = local.image_tag
  }
  provisioner "local-exec" {
    command = <<EOT
      az acr login --name ${azurerm_container_registry.acr.name}
      docker push ${local.api_docker_image_acr_tag}
      docker logout ${azurerm_container_registry.acr.login_server}
    EOT
  }

  depends_on = [null_resource.build-api-image, azurerm_container_registry.acr]
}



output "appUrl" {
  value = "https://${azurerm_container_app.app.latest_revision_fqdn}"
}



