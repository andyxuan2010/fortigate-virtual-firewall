provider "azurerm" {
  features {}
}

provider "azurerm" {
  features {}
  alias = "prod"
}

provider "azurerm" {
  features {}
  alias = "nonprod"
}

provider "azurerm" {
  features {}
  alias = "sbx"
}

provider "azurerm" {
  features {}
  alias           = "hub"
  subscription_id = trimspace(var.hub_vnet_subscription_id) != "" ? trimspace(var.hub_vnet_subscription_id) : null
}

data "azurerm_subscriptions" "available" {}
