subscription_id     = "9a5b7a0d-3a54-4dd3-b9a8-5a89ed84e3ab"
resource_group_name = "hutest"
location            = "westeurope"

postgres = {
  sku_name                      = "B_Standard_B1ms"
  public_network_access_enabled = false
}

pgadmin = {
  image  = "docker.io/dpage/pgadmin4:8.12.0"
  cpu    = 0.25
  memory = "0.5Gi"
}

sampleApi = {
  image  = "sample-api"
  cpu    = 0.25
  memory = "0.5Gi"
}

