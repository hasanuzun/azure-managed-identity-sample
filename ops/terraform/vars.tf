variable "subscription_id" {
  description = "The ID of the subscription"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "location" {
  description = "The location of the resources"
  type        = string
}

variable "postgres" {
  description = "Postgres configuration"
  type = object({
    sku_name                      = string
    public_network_access_enabled = bool
  })
}


variable "pgadmin" {
  description = "PgAdmin configuration"
  type = object({
    image  = string
    cpu    = number
    memory = string
  })
}

variable "sampleApi" {
  description = "Sample-Api configuration"
  type = object({
    image  = string
    cpu    = number
    memory = string
  })
}
