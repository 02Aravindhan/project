resource "azurerm_resource_group" "onpremises-rg" {
  name     = var.resource_group_name
  location = var.location
}
resource "azurerm_virtual_network" "onpremises-vnets" {
  for_each = var.vnets

  name                = each.key
  address_space       = [each.value.address_space]
  location            = azurerm_resource_group.onpremises-rg.location
  resource_group_name = azurerm_resource_group.onpremises-rg.name
  depends_on          = [azurerm_resource_group.onpremises-rg]
}
resource "azurerm_subnet" "subnets" {
  for_each = var.subnets

  name   = each.key
  address_prefixes =[each.value.address_prefix]
  resource_group_name = azurerm_resource_group.onpremises-rg.name
  depends_on = [ azurerm_resource_group.onpremises-rg , azurerm_virtual_network.onpremises-vnets]
  virtual_network_name = azurerm_virtual_network.onpremises-vnets["vnets"].name
}
//create the network interface
resource "azurerm_network_interface" "onpremises-nic" {
  name                = "onpremises-nic"
  location            = azurerm_resource_group.onpremises-rg.location
  resource_group_name = azurerm_resource_group.onpremises-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnets["subnet"].id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [ azurerm_resource_group.onpremises-rg,azurerm_subnet.subnets ]
}

resource "azurerm_public_ip" "onpremises-ip" {
  name                = "public-ip"
  location            = azurerm_resource_group.onpremises-rg.location
  resource_group_name = azurerm_resource_group.onpremises-rg.name
  sku = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_virtual_network_gateway" "onpremises-gateway" {
  name                = "vpn-gateway"
  location            = azurerm_resource_group.onpremises-rg.location
  resource_group_name = azurerm_resource_group.onpremises-rg.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  //gateway_subnet_id   = azurerm_subnet.gateway_subnet.id

  ip_configuration {
    name                          = "config1"
    subnet_id = azurerm_subnet.subnets["GatewaySubnet"].id
    public_ip_address_id          = azurerm_public_ip.onpremises-ip.id
    private_ip_address_allocation = "Dynamic"

    
  }
  depends_on = [ azurerm_resource_group.onpremises-rg,azurerm_subnet.subnets,azurerm_public_ip.onpremises-ip ]
}

# #  the data from Hub Gateway Public_IP (IP_addr)
# data "azurerm_public_ip" "Hub-VPN-GW-public-ip" {
#  name = "GatewaySubnet-IP"
#   resource_group_name = "hub-rg"
# }

# #  the data from hub Virtual Network (address_space)
# data "azurerm_virtual_network" "hub-vnets" {
#   name = "Hub-vnet"
#   resource_group_name = "hub-rg"
# }
# # Create the Local Network Gateway for VPN Gateway
# resource "azurerm_local_network_gateway" "OnPremises_local_gateway" {
#   name                = "OnPremises-To-Hub"
#   location            = azurerm_resource_group.onpremises-rg.location
#   resource_group_name = azurerm_resource_group.onpremises-rg.name
#   gateway_address     = data.azurerm_public_ip.Hub-VPN-GW-public-ip.ip_address
#   address_space       = [data.azurerm_virtual_network.hub-vnets.address_space]
#   depends_on = [ azurerm_public_ip.onpremises-ip , azurerm_virtual_network_gateway.onpremises-gateway ,
#                #data.azurerm_public_ip. ,
#                 data.azurerm_virtual_network.hub-vnets ]
# }
# # Create the VPN-Connection for Connect the Networks
# resource "azurerm_virtual_network_gateway_connection" "vpn_connection" {
#   name                = "OnPremises-Hub-vpn-connect"
#   location            = azurerm_resource_group.onpremises-rg.location
#   resource_group_name = azurerm_resource_group.onpremises-rg.name
#   virtual_network_gateway_id     = azurerm_virtual_network_gateway.onpremises-gateway.id
#   local_network_gateway_id       = azurerm_local_network_gateway.OnPremises_local_gateway.id
#   type                           = "IPsec"
#   connection_protocol            = "IKEv2"
#   shared_key                     = "SharedKey"

#   depends_on = [ azurerm_virtual_network_gateway.onpremises-gateway , azurerm_local_network_gateway.OnPremises_local_gateway]
# }
#create the vm and assign the nic to vm
resource "azurerm_windows_virtual_machine" "onpremises-vm" {
  name = "subnets-vm"
  resource_group_name = azurerm_resource_group.onpremises-rg.name
  location = azurerm_resource_group.onpremises-rg.location
  size                  = "Standard_DS1_v2"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.onpremises-nic.id]

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
 depends_on = [azurerm_resource_group.onpremises-rg, azurerm_network_interface.onpremises-nic ]
}

#create a route table
resource "azurerm_route_table" "spoke1-udr" {

  name = "onpremises-udr-to-spoke1"
  location = azurerm_resource_groups.spoke_1rg.location
  resource_group_name = azurerm_resource_group.spoke_1rg.name

  route {
    name = "route-to-firewall"
    address_prefix = "10.2.0.0/16"
    next_hop_type = "VirtualNetworkGateway"
  
  }
  
}

# Associate the route table with  subnet
resource "azurerm_subnet_route_table_association" "routetable--Associate" {
   subnet_id                 = azurerm_subnet.subnets["subnets-vm"].id
   route_table_id = azurerm_route_table.spoke1-udr.id
   depends_on = [ azurerm_subnet.subnets , azurerm_route_table.spoke1-udr ]
}