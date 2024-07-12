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
  name                = "onpremises-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnets["subnet"].id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [ azurerm_resource_group.rg,azurerm_subnet.subnets ]
}
resource "azurerm_public_ip" "ip" {
  name                = "public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}
resource "azurerm_virtual_network_gateway" "vnetgateway" {
  name                = "vpn-gateway"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  //gateway_subnet_id   = azurerm_subnet.gateway_subnet.id

  ip_configuration {
    name                          = "config1"
    subnet_id = azurerm_subnet.subnets["GatewaySubnet"].id
    public_ip_address_id          = azurerm_public_ip.rg.id
    private_ip_address_allocation = "Dynamic"

    
  }
  depends_on = [ azurerm_resource_group.rg,azurerm_subnet.subnets,azurerm_public_ip.rg ]
}
data "azurerm_virtual_network" "vnets" {
  name = "Hub-vnet"
  resource_group_name = "hub-rg"
}
# Create the Local Network Gateway for VPN Gateway
resource "azurerm_local_network_gateway" "OnPremises_local_gateway" {
  name                = "OnPremises-To-Hub"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  gateway_address     = data.azurerm_public_ip.Hub-VPN-GW-public-ip.ip_address
  address_space       = [data.azurerm_virtual_network.vnets.address_space[0]]
  depends_on = [ azurerm_public_ip.public_ips , azurerm_virtual_network_gateway.gateway ,
               data.azurerm_public_ip.Hub-VPN-GW-public-ip , data.azurerm_virtual_network.Hub_vnet ]
}


resource "azurerm_virtual_machine" "vm" {
  name                  = "onpremises-vm1"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  os_profile {
    computer_name  = "hostname"
    admin_username = "adminuser"
    admin_password = "Password1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = "Production"
  }
  depends_on = [ azurerm_resource_group.rg,azurerm_network_interface.nic ]
}



