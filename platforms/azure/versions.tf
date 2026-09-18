terraform {
  required_version = ">=1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }

    azapi = {
      source = "Azure/azapi"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.0"
    }

    msgraph = {
      source  = "microsoft/msgraph"
      version = ">= 0.3"
    }

    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}
