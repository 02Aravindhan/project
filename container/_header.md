1. we should create the Resource Group.
 2.We create the Azure Blob Storage account in resource group.
  3.Finally we create the Storage account container to store the state files.

Configuration :
  backend "azurerm" {
    resource_group_name  =  "RemoteState-rg"   //   Resource Group
    storage_account_name = "storageaccount"    //   Storage account 
    container_name       = "storage-Container"       //  storage account container
    key                  = ""             
  }