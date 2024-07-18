output "hub-rg" {
  value = azurerm_resource_group.hub-rg
}

output "hub-vnet" {
  value = azurerm_virtual_network.hub-vnets
}

output "subnets" {
  value = azurerm_subnet.subnets
}
 output "hub-Public-ip" {
  value = azurerm_public_ip.hub-public-ip
 }
#   output "hub-Gateway" {
#   value = azurerm_virtual_network_gateway.hub-gateway
#  }
