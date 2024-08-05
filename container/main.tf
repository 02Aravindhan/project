# Create the Resource Group
resource "azurerm_resource_group" "rg" {
  name = var.resource_group_name
  location = var.location
}

# Create the Storage Account
resource "azurerm_storage_account" "storageaccount" {
  name = var.storage_account_name
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  account_tier = "Standard"
  account_replication_type = "LRS"
  depends_on = [ azurerm_resource_group.rg ]
}

# Create the Storage Account Container to store the state files
resource "azurerm_storage_container" "storage-container" {
  name = var.container_name
  storage_account_name = azurerm_storage_account.storageaccount.name
  container_access_type = "private"
}


 