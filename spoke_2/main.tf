resource "azurerm_resource_group" "spoke_2rg" {
  name     = var.resource_group_name
  location = var.location
}
resource "azurerm_virtual_network" "spoke2-vnets" {
  for_each = var.vnets

  name                = each.key
  address_space       = [each.value.address_space]
  location            = azurerm_resource_group.spoke_2rg.location
  resource_group_name = azurerm_resource_group.spoke_2rg.name
  depends_on          = [azurerm_resource_group.spoke_2rg]
}
resource "azurerm_subnet" "subnets" {
  for_each = var.subnets
  name   = each.key
  address_prefixes =[each.value.address_prefix]
  resource_group_name = azurerm_resource_group.spoke_2rg.name
  depends_on = [ azurerm_resource_group.spoke_2rg , azurerm_virtual_network.spoke2-vnets]
  virtual_network_name = azurerm_virtual_network.spoke2-vnets["spoke2-vnets"].name
}
//Create the Network Security Group with Rules
resource "azurerm_network_security_group" "spoke2-nsg" {
  for_each = toset(local.subnet_names)
  name = each.key
  resource_group_name = azurerm_resource_group.spoke_2rg.name
  location = azurerm_resource_group.spoke_2rg.location

  dynamic "security_rule" {                           
     for_each = { for rule in local.rules : rule.name => rule }
     content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }
  depends_on = [ azurerm_subnet.subnets ]
  
}


resource "azurerm_public_ip" "public-ip" {
  name                = "PublicIP"
  location            = azurerm_resource_group.spoke_2rg.location
  resource_group_name = azurerm_resource_group.spoke_2rg.name
  allocation_method   = "Static"
  sku = "Standard"
}

//gateway
resource "azurerm_application_gateway" "spoke2-appgateway" {
name = "spoke2-appgateway"
location = azurerm_resource_group.spoke_2rg.location
resource_group_name = azurerm_resource_group.spoke_2rg.name
sku {
name = "Standard_v2"
tier = "Standard_v2"
capacity = 2
}
 
gateway_ip_configuration {
name = "appGatewayIpConfig"
subnet_id =azurerm_subnet.subnets["subnet2"].id
}
 
frontend_ip_configuration {
name = "appGatewayFrontendIP"
public_ip_address_id = azurerm_public_ip.public-ip.id
}

 
frontend_port {
name = "appGatewayFrontendPort"
port = 80
}
 
# ssl_certificate {
# name = "examplecert"
# key_vault_secret_id = azurerm_key_vault_certificate.rg.secret_id
# }
 
http_listener {
name = "appGatewayListener"
frontend_ip_configuration_name = "appGatewayFrontendIP"
frontend_port_name = "appGatewayFrontendPort"
protocol = "Http"    //https in use

//ssl_certificate_name = "examplecert"
}
 
backend_address_pool {
name = "appGatewayBackendPool"
}
 
backend_http_settings {
name = "appGatewayBackendHttpSettings"
cookie_based_affinity = "Disabled"
port = 80
protocol = "Http"
request_timeout = 20
}
 
request_routing_rule {
name = "appGatewayRule"
rule_type = "Basic"
http_listener_name = "appGatewayListener"
backend_address_pool_name = "appGatewayBackendPool"
backend_http_settings_name = "appGatewayBackendHttpSettings"
}
depends_on = [ azurerm_resource_group.spoke_2rg,azurerm_subnet.subnets,azurerm_public_ip.public-ip ]

}
# key vault
data "azurerm_key_vault" "Key_vault" {
  name                = "KeyVault4648"
  resource_group_name = "onpremises-rg"
}

#  username 
data "azurerm_key_vault_secret" "vm_admin_username" {
  name         = "onpremiseskeyvault8818"
  key_vault_id = data.azurerm_key_vault.Key_vault.id
}

#  password 
data "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "onpremiseskeyvault8818password"
  key_vault_id = data.azurerm_key_vault.Key_vault.id
}

//vmss

resource "azurerm_windows_virtual_machine_scale_set" "vmss" {
  name                = "myvmss"
  resource_group_name = azurerm_resource_group.spoke_2rg.name
  location = azurerm_resource_group.spoke_2rg.location
  sku = "Standard_DS1_v2"
  instances = 2
  admin_username = data.azurerm_key_vault_secret.vm_admin_username.value
  admin_password = data.azurerm_key_vault_secret.vm_admin_password.value
 
  network_interface {
    name = "myvmss"
    primary = true
    ip_configuration {
      name = "internal"
      subnet_id = azurerm_subnet.subnets["Subnet1"].id
      application_gateway_backend_address_pool_ids = [local.app_gateway_backend_address_id[0]]

    }
  }
  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

# connect the data from Hub Vnet for peering the Spoke_2 Vnet (Spoke_2 <--> Hub)
data "azurerm_virtual_network" "hub_vnets" {
  name = "hub_vnets"
  resource_group_name = "hub-rg"
}

# Establish the Peering between Spoke_2 and Hub networks (Spoke_2 <--> Hub)
resource "azurerm_virtual_network_peering" "Spoke_2-To-hub" {
  name                      = "Spoke_2-To-hub"
  resource_group_name       = azurerm_resource_group.spoke_2rg.name
  virtual_network_name      = azurerm_virtual_network.spoke2-vnets["spoke2-vnets"].name
  remote_virtual_network_id = data.azurerm_virtual_network.hub_vnets.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.spoke2-vnets, data.azurerm_virtual_network.hub_vnets  ]
}
# Establish the Peering between  Hub and Spoke-2 networks (Hub <--> Spoke_02)
resource "azurerm_virtual_network_peering" "hub-To-Spoke-2" {
  name                      = "hub-To-Spoke_2"
  resource_group_name       = data.azurerm_virtual_network.hub_vnets.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.hub_vnets.name
  remote_virtual_network_id = azurerm_virtual_network.spoke2-vnets["spoke2-vnets"].id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.spoke2-vnets , data.azurerm_virtual_network.hub_vnets ]
}


 # #route table for connect spoke2 t0 spoke1 through firewall

resource "azurerm_route_table" "spoke2-udr" {
  name = "spoke2-udr-to-firewall"
  location = azurerm_resource_group.spoke_2rg.location
  resource_group_name = azurerm_resource_group.spoke_2rg.name

  route {
    name = "route-to-firewall"
    address_prefix = "10.2.1.0/24" //SPOKE_1 ip
    next_hop_type = "VirtualAppliance"
    next_hop_in_ip_address = "10.1.0.4"
  }
  depends_on = [ azurerm_resource_group.spoke_2rg ]
  
}
//spoke_2udr_subnet_association
resource "azurerm_subnet_route_table_association" "spoke2udr_subnet_association" {
    for_each = var.subnets

    subnet_id = azurerm_subnet.subnets[each.key].id
    route_table_id = azurerm_route_table.spoke2-udr.id
    depends_on = [ azurerm_route_table.spoke2-udr,azurerm_subnet.subnets,azurerm_route_table.spoke2-udr ]
}

