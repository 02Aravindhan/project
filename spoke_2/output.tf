output "spoke_2rg" {
  value = azurerm_resource_group.spoke_2rg
}

output "Spoke_2vnet" {
  value = azurerm_virtual_network.spoke2-vnet
}

output "subnets" {
  value = azurerm_subnet.subnets
}

output "public_ip" {
  value = azurerm_public_ip.public-ip
}

output "spoke2-appgateway" {
  value = azurerm_application_gateway.spoke2-appgateway
}

# output "route_table_ids" {

#   value = {
#     spoke1_udr = azurerm_route_table.spoke1-udr.id
#     spoke2_udr = azurerm_route_table.spoke2-udr.id
#   }
# }