output "spoke_1rg" {
    value = azurerm_resource_group.spoke_1rg 
}

output "Spoke_1vnet" {
  value = azurerm_virtual_network.spoke_1vnets
}

output "subnets" {
  value = azurerm_subnet.subnets
}

 output "spoke_1vm" {
   value = azurerm_windows_virtual_machine.spoke_1vm
 }



output "Key_Vault" {
  value = azurerm_key_vault.Key_Vault
}



 output "fileshare" {
   value = azurerm_storage_share.fileshare
 }