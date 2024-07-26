output "OnPremise-rg" {
  value = azurerm_resource_group.onpremises-rg
}

output "onpremises-vnets" {
  value = azurerm_virtual_network.onpremises-vnets
}

output "subnets" {
  value = azurerm_subnet.subnets
}

output "onpremises-ip" {
 value = azurerm_public_ip.onpremises-ip
}

 output "onpremises-Gateway" {
  value = azurerm_virtual_network_gateway.onpremises-gateway
 }