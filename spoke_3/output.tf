output "Spoke-3rg" {
  value = azurerm_resource_group.spoke-3rg
}
output "vnets" {
  value = azurerm_virtual_network.spoke-3vnets
  
}

output "app_plan" {
  value = azurerm_app_service_plan.spoke-3plan
}

output "sp3-appservice" {
  value = azurerm_app_service.spoke-3app-services
}