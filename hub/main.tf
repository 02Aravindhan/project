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
  virtual_network_name = azurerm_virtual_network.vnets["vnets"].name
}
resource "azurerm_public_ip" "hub-public-ip" {
  for_each = toset(local.subnetname)
  name = "${each.key}-IP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on = [ azurerm_resource_group.rg ]
}
resource "azurerm_network_interface" "hub-nic" {
  for_each = toset([for i in azurerm_subnet.subnets : i.name])
  name                ="${each.key}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnets[each.key].id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [ azurerm_resource_group.rg,azurerm_subnet.subnets ]
}


