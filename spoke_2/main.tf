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
resource "azurerm_public_ip" "rg" {
  name                = "PublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}
resource "azurerm_application_gateway" "rg" {
name = "spoke2-appgateway"
location = azurerm_resource_group.rg.location
resource_group_name = azurerm_resource_group.rg.name
sku {
name = "Standard_v2"
tier = "Standard_v2"
capacity = 2
}
 
gateway_ip_configuration {
name = "appGatewayIpConfig"
subnet_id =azurerm_subnet.subnets.id
}
 
frontend_ip_configuration {
name = "appGatewayFrontendIP"
public_ip_address_id = azurerm_public_ip.rg.id
}
 
frontend_port {
name = "appGatewayFrontendPort"
port = 443
}
 
ssl_certificate {
name = "examplecert"
key_vault_secret_id = azurerm_key_vault_certificate.rg.secret_id
}
 
http_listener {
name = "appGatewayListener"
frontend_ip_configuration_name = "appGatewayFrontendIP"
frontend_port_name = "appGatewayFrontendPort"
protocol = "Https"
ssl_certificate_name = "examplecert"
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
}
resource "azurerm_windows_virtual_machine_scale_set" "vmss" {
  name                = "myvmss"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  sku = "Standard_DS1_v2"
  instances = 2
  admin_username = data.azurerm_key_vault_secret.admin_username.value
  admin_password = data.azurerm_key_vault_secret.admin_password.value
 
  network_interface {
    name = "myvmss"
    primary = true
    ip_configuration {
      name = "internal"
      subnet_id = azurerm_subnet.subnets.id
      application_gateway_backend_address_pool_ids = [local.application_gateway_backend_address_pool_ids[0]]
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



