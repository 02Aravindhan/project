resource "azurerm_resource_group" "spoke-3rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "spoke-3vnets" {
  for_each = var.vnets

  name                = each.key
  address_space       = [each.value.address_space]
  location            = azurerm_resource_group.spoke-3rg.location
  resource_group_name = azurerm_resource_group.spoke-3rg.name
  depends_on          = [azurerm_resource_group.spoke-3rg]
 }


resource "azurerm_subnet" "AppServiceSubnet" {
  for_each = var.subnets

  name   = each.key
  address_prefixes =[each.value.address_prefix]
  resource_group_name = azurerm_resource_group.spoke-3rg.name
  depends_on = [ azurerm_resource_group.spoke-3rg , azurerm_virtual_network.spoke-3vnets]
  virtual_network_name = azurerm_virtual_network.spoke-3vnets["spoke-3vnets"].name
   delegation {
    name = "appservice_delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }
}

//app_service_plan
resource "azurerm_app_service_plan" "spoke-3plan" {
  name                = "app-service-plan"
  resource_group_name =azurerm_resource_group.spoke-3rg.name 
  location = azurerm_resource_group.spoke-3rg.location
  
  sku {
    tier = "Basic"   
    size = "B1"      
  }
  depends_on = [ azurerm_resource_group.spoke-3rg ]
 }

//app_service

resource "azurerm_app_service" "spoke-3app-services" {
  name                = "sp3-appservice"  
  location            =azurerm_resource_group.spoke-3rg.location          
  resource_group_name = azurerm_resource_group.spoke-3rg.name  

  app_service_plan_id = azurerm_app_service_plan.spoke-3plan.id 
  
  depends_on = [ azurerm_resource_group.spoke-3rg,azurerm_app_service_plan.spoke-3plan ]
  
}

# integrate to hub
resource "azurerm_app_service_virtual_network_swift_connection" "vnet-integration" {
  app_service_id = azurerm_app_service.spoke-3app-services.id
  subnet_id = azurerm_subnet.AppServiceSubnet["AppServiceSubnet"].id
  depends_on = [ azurerm_app_service.spoke-3app-services , azurerm_subnet.AppServiceSubnet ]
}


 #  connect to hub(Spoke-3 <--> Hub)

data "azurerm_virtual_network" "hub_vnets" {
  name ="hub_vnets"
  resource_group_name = "hub-rg"
}

# connect to peering spoke3 to hub (Spoke3 <--> hub)
resource "azurerm_virtual_network_peering" "Spoke3-To-hub" {
  name                      = "Spoke3-To-hub"
  resource_group_name       = azurerm_resource_group.spoke-3rg.name
  virtual_network_name      = azurerm_virtual_network.spoke-3vnets["spoke-3vnets"].name
  remote_virtual_network_id = data.azurerm_virtual_network.hub_vnets.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.spoke-3vnets , data.azurerm_virtual_network.hub_vnets  ]
}

#connectto peering hub to spoke3(hub <--> Spoke3)
resource "azurerm_virtual_network_peering" "hub-To-Spoke3" {
  name                      = "hub-Spoke3"
  resource_group_name       = data.azurerm_virtual_network.hub_vnets.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.hub_vnets.name
  remote_virtual_network_id = azurerm_virtual_network.spoke-3vnets["spoke-3vnets"].id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.spoke-3vnets , data.azurerm_virtual_network.hub_vnets ]
}