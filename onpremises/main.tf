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
  virtual_network_name = azurerm_virtual_network.onpremises-vnets["onpremises-vnets"].name
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

data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

# key_vault
resource "azurerm_key_vault" "Key_vault" {
  name                        = "KeyVault4646"
  resource_group_name = azurerm_resource_group.onpremises-rg.name
  location = azurerm_resource_group.onpremises-rg.location
  sku_name                    = "standard"
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled    = true
  soft_delete_retention_days = 30
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azuread_client_config.current.object_id
 
    secret_permissions = [
      "Get",
      "Set",
    ]
  }
  depends_on = [ azurerm_resource_group.onpremises-rg ]
}

// Key vault Username
 
resource "azurerm_key_vault_secret" "vm_admin_username" {
  name         = "onpremiseskeyvault8818"
  value        = var.admin_username
  key_vault_id = azurerm_key_vault.Key_vault.id
  depends_on = [ azurerm_key_vault.Key_vault ]
}
 
// Key vault Password
 
resource "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "onpremiseskeyvault8818password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.Key_vault.id
  depends_on = [ azurerm_key_vault.Key_vault ]
}


//onpremises-gateway

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

#  the data from Hub Gateway Public_IP (IP_addr)
data "azurerm_public_ip" "Hub-VPN-GW-public-ip" {
 name = "GatewaySubnet-ip"
  resource_group_name = "hub-rg"
}

#  the data from hub Virtual Network (address_space)
data "azurerm_virtual_network" "hub_vnets" {
  name = "hub_vnets"
  resource_group_name = "hub-rg"
}
# Create the Local Network Gateway for VPN Gateway
resource "azurerm_local_network_gateway" "OnPremises_local_gateway" {
  name                = "OnPremises-To-Hub"
  location            = azurerm_resource_group.onpremises-rg.location
  resource_group_name = azurerm_resource_group.onpremises-rg.name
  gateway_address     = data.azurerm_public_ip.Hub-VPN-GW-public-ip.ip_address
  address_space       = [data.azurerm_virtual_network.hub_vnets.address_space[0]]
  depends_on = [ azurerm_public_ip.onpremises-ip  ,
                data.azurerm_virtual_network.hub_vnets ]
}

# Create the VPN-Connection for Connect the Networks
resource "azurerm_virtual_network_gateway_connection" "vpn_connection" {
  name                = "OnPremises-Hub-vpn-connect"
  location            = azurerm_resource_group.onpremises-rg.location
  resource_group_name = azurerm_resource_group.onpremises-rg.name
  virtual_network_gateway_id     = azurerm_virtual_network_gateway.onpremises-gateway.id
  local_network_gateway_id       = azurerm_local_network_gateway.OnPremises_local_gateway.id
  type                           = "IPsec"
  connection_protocol            = "IKEv2"
  shared_key                     = "SharedKey"

  depends_on = [  azurerm_virtual_network_gateway.onpremises-gateway,azurerm_local_network_gateway.OnPremises_local_gateway]
}

//create the vm and assign the nic to vm
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
resource "azurerm_route_table" "onpremises-udr-spoke1" {
  name = "onpremises-udr-spoke1"
  location = azurerm_resource_group.onpremises-rg.location
  resource_group_name = azurerm_resource_group.onpremises-rg.name

  route {
    name = "route-to-firewall"
    address_prefix = "10.2.0.0/16"   //spoke_1 ip  sp1 to onprem udr
    next_hop_type = "VirtualAppliance"
    next_hop_in_ip_address = "10.1.0.4"
    
  }
  depends_on = [ azurerm_resource_group.onpremises-rg ]
}

#Associate the route table with  subnet
resource "azurerm_subnet_route_table_association" "routetable--Associate" {
   subnet_id                 = azurerm_subnet.subnets["subnet"].id
   route_table_id = azurerm_route_table.onpremises-udr-spoke1.id
   depends_on = [ azurerm_subnet.subnets , azurerm_route_table.onpremises-udr-spoke1 ]
}