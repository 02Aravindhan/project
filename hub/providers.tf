terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }
   required_version = ">= 1.1.0"
   backend "azurerm" {
    resource_group_name = "RemoteState-rg"
    storage_account_name = "storage88account"
    container_name = "storage-container"
    key = "hub-backend.tfstate"
    
  }

}


provider "azurerm" {
  features {}
}
