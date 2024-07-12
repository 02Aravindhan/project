resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}
resource "azurerm_virtual_network" "vnets" {
  for_each = var.vnets

  name                = each.key
  address_space       = [each.value.address_space]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  depends_on          = [azurerm_resource_group.rg]
}
resource "azurerm_subnet" "subnets" {
  for_each = var.subnets

  name   = each.key
  address_prefixes =[each.value.address_prefix]
  resource_group_name = azurerm_resource_group.rg.name
  depends_on = [ azurerm_resource_group.rg , azurerm_virtual_network.vnets]
  virtual_network_name = azurerm_virtual_network.vnets["vnets"].name
}
resource "azurerm_network_interface" "nic" {
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

  resource "azurerm_windows_virtual_machine" "vm" {
  for_each = toset(local.subnetname)
  name                  = "${each.key}-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                  = "Standard_DS1_v2"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic[each.key].id]
 
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
 
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  depends_on = [azurerm_resource_group.rg, azurerm_network_interface.nic]
}

resource "azurerm_storage_account" "rg" {
  name                     = "storageaccount"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = "East US"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
resource "azurerm_storage_share" "rg" {
  name                 = "fileshare"
  storage_account_name = azurerm_storage_account.rg.name
  quota                = 50
}


 