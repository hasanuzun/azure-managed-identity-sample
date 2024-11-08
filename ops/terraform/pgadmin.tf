locals {
  pgadmin_port = 5050
  # https://www.pgadmin.org/docs/pgadmin4/development/config_py.html
  pgadmin_oauth_config = <<EOT
[
    { 
        'OAUTH2_NAME': 'azuread',
        'OAUTH2_DISPLAY_NAME': 'Azure AD Login',
        'OAUTH2_CLIENT_ID': '${azuread_application_registration.aad-app.client_id}',
        'OAUTH2_CLIENT_SECRET': '${azuread_application_password.aad-app-secret.value}',
        'OAUTH2_AUTHORIZATION_URL': 'https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/oauth2/v2.0/authorize',
        'OAUTH2_TOKEN_URL': 'https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/oauth2/v2.0/token',
        'OAUTH2_API_BASE_URL': 'https://graph.microsoft.com/v1.0/', 
        'OAUTH2_USERINFO_ENDPOINT': 'me',
        'OAUTH2_SERVER_METADATA_URL': 'https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0/.well-known/openid-configuration',
        'OAUTH2_ICON': None,
        'OAUTH2_BUTTON_COLOR': None,
        'OAUTH2_SCOPE': 'User.Read openid email profile',
        'OAUTH2_ADDITIONAL_CLAIMS': None 
        'OAUTH2_USERNAME_CLAIM': 'email'
    }
]
EOT
}

resource "azurerm_container_app" "pgadmin" {
  name                         = "${azurerm_resource_group.rg.name}-pgadmin"
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
    target_port                = local.pgadmin_port
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  secret {
    name  = "oauthconfig"
    value = local.pgadmin_oauth_config
  }

  secret {
    name  = "adminemail"
    value = "dummy@dummy.com" # Dummy, login with only Azure AD activated
  }

  secret {
    name  = "adminpass"
    value = "DummyPasswordNotActive" # Dummy, login with only Azure AD activated
  }

  template {
    container {
      name   = "${azurerm_resource_group.rg.name}-pgadmin"
      image  = var.pgadmin.image
      cpu    = var.pgadmin.cpu
      memory = var.pgadmin.memory

      env {
        name  = "PGADMIN_CONFIG_AUTHENTICATION_SOURCES"
        value = "['oauth2']"
      }

      env {
        name        = "PGADMIN_CONFIG_OAUTH2_CONFIG"
        secret_name = "oauthconfig"
      }

      env {
        name        = "PGADMIN_DEFAULT_EMAIL"
        secret_name = "adminemail"
      }

      env {
        name        = "PGADMIN_DEFAULT_PASSWORD"
        secret_name = "adminpass"
      }

      env {
        name  = "PGADMIN_DISABLE_POSTFIX"
        value = "true"
      }

      env {
        name  = "PGADMIN_LISTEN_PORT"
        value = local.pgadmin_port
      }

      env {
        name  = "TZ"
        value = "Europe/Berlin"
      }
    }
  }
}


resource "azuread_application_redirect_uris" "aad-app-redirect-uris" {
  application_id = azuread_application_registration.aad-app.id
  type           = "Web"

  redirect_uris = [
    "https://${azurerm_container_app.pgadmin.ingress.0.fqdn}/oauth2/authorize",
    "https://${azurerm_container_app.pgadmin.latest_revision_fqdn}/oauth2/authorize"
  ]
}


output "pgAdminUrl" {
  value = "https://${azurerm_container_app.pgadmin.latest_revision_fqdn}"
}

