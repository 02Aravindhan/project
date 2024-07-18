resource "azurerm_resource_group" "hub-rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "hub-vnets" {
  for_each = var.vnets

  name                = each.key
  address_space       = [each.value.address_space]
  location            = azurerm_resource_group.hub-rg.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  depends_on          = [azurerm_resource_group.hub-rg]
}
resource "azurerm_subnet" "subnets" {
  for_each = var.subnets

  name   = each.key
  address_prefixes =[each.value.address_prefix]
  resource_group_name = azurerm_resource_group.hub-rg.name
  depends_on = [ azurerm_resource_group.hub-rg , azurerm_virtual_network.hub-vnets]
  virtual_network_name = azurerm_virtual_network.hub-vnets["vnets"].name
}
resource "azurerm_public_ip" "hub-public-ip" {
  for_each = toset(local.subnetname)
  name = "${each.key}-IP"
  location            = azurerm_resource_group.hub-rg.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on = [ azurerm_resource_group.hub-rg ]
}
resource "azurerm_network_interface" "hub-nic" {
  for_each = toset([for i in azurerm_subnet.subnets : i.name])
  name                ="${each.key}-nic"
  location            = azurerm_resource_group.hub-rg.location
  resource_group_name = azurerm_resource_group.hub-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnets[each.key].id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [ azurerm_resource_group.hub-rg,azurerm_subnet.subnets ]
}
resource "azurerm_virtual_network_gateway" "hub-gateway" {
  name                = "hub-vpn-gateway"
  location            = azurerm_resource_group.hub-rg.location
  resource_group_name = azurerm_resource_group.hub-rg.name
 
  type     = "Vpn"
  vpn_type = "RouteBased"
  active_active = false
  
  sku           = "VpnGw1"
 
  ip_configuration {
    name                = "vnetGatewayConfig"
    public_ip_address_id = azurerm_public_ip.hub-public-ip["Gatewaysubnets"].id

    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_subnet.subnets["GatewaySubnets"].id
  }
  depends_on = [ azurerm_resource_group.hub-rg , azurerm_public_ip.hub-public-ip , azurerm_subnet.subnets ]
}
# #  the data from onpremises Gateway Public_IP (IP_addr)
# data "azurerm_public_ip" "onpremises-VPN-GW-public-ip" {
#  name = "GatewaySubnet-IP"
#   resource_group_name = "hub-rg"
# }

# #  the data from hub Virtual Network (address_space)
# data "azurerm_virtual_network" "onpremises-vnets" {
#   name = "onpremises-vnet"
#   resource_group_name = "onpremises-rg"
# }



