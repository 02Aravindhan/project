resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}
resource "azurerm_app_service_plan" "rg1" {
  name                = "app-service-plan"
  resource_group_name =azurerm_resource_group.rg.name 
  location = azurerm_resource_group.rg.location
  
  sku {
    tier = "Basic"   
    size = "B1"      
  }
}
resource "azurerm_app_service" "rg2" {
  name                = "app-service"  
  location            =azurerm_resource_group.rg.location          
  resource_group_name = azurerm_resource_group.rg.name  

  app_service_plan_id = azurerm_app_service_plan.rg.id  
}