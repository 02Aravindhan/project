terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }
  backend "azurerm" {
    resource_group_name = "RemoteState-rg"
    storage_account_name = "storage88account"
    container_name = "storage-container"
    key = "spoke3-backend.tfstate"
    
  }


  required_version = ">= 1.1.0"
}


provider "azurerm" {
  features {}
}
