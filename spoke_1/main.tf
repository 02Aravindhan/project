data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}
 

resource "azurerm_resource_group" "spoke_1rg" {
  name     = var.resource_group_name
  location = var.location
}
resource "azurerm_virtual_network" "spoke_1vnets" {
  for_each = var.vnets

  name                = each.key
  address_space       = [each.value.address_space]
  location            = azurerm_resource_group.spoke_1rg.location
  resource_group_name = azurerm_resource_group.spoke_1rg.name
  depends_on          = [azurerm_resource_group.spoke_1rg]
}
resource "azurerm_subnet" "subnets" {
  for_each = var.subnets

  name   = each.key
  address_prefixes =[each.value.address_prefix]
  resource_group_name = azurerm_resource_group.spoke_1rg.name
  depends_on = [ azurerm_resource_group.spoke_1rg , azurerm_virtual_network.spoke_1vnets]
  virtual_network_name = azurerm_virtual_network.spoke_1vnets["vnets"].name
}
resource "azurerm_network_interface" "spoke-1nic" {
  for_each = toset([for i in azurerm_subnet.subnets : i.name])
  name                ="${each.key}-nic"
  location            = azurerm_resource_group.spoke_1rg.location
  resource_group_name = azurerm_resource_group.spoke_1rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnets[each.key].id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [ azurerm_resource_group.spoke_1rg,azurerm_subnet.subnets ]
 }
resource "azurerm_key_vault" "Key_vault" {
  name                        = "KeyVault8818"
  resource_group_name = azurerm_resource_group.spoke_1rg.name
  location = azurerm_resource_group.spoke_1rg.location
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
  depends_on = [ azurerm_resource_group.spoke_1rg ]
}
# Create the Network Security Group with Rules
resource "azurerm_network_security_group" "spoke_1nsg" {
  for_each = toset(local.subnet_names)
  name = each.key
  resource_group_name = azurerm_resource_group.spoke_1rg.name
  location = azurerm_resource_group.spoke_1rg.location

  dynamic "security_rule" {                           
     for_each = { for rule in local.rules_csv : rule.name => rule }
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
  depends_on = [ azurerm_resource_group.spoke_1rg,azurerm_subnet.subnets ]
  
}

// Key vault Username
 
resource "azurerm_key_vault_secret" "vm_admin_username" {
  name         = "spokekeyvault8818"
  value        = var.admin_username
  key_vault_id = azurerm_key_vault.Key_vault.id
  depends_on = [ azurerm_key_vault.Key_vault ]
}
 
// Key vault Password
 
resource "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "spokekeyvault8818password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.Key_vault.id
  depends_on = [ azurerm_key_vault.Key_vault ]
}
 

#   resource "azurerm_windows_virtual_machine" "spoke_1vm" {
#   for_each = toset(local.subnetname)
#   name                  = "${each.key}-vm"
#   location            = azurerm_resource_group.spoke_1rg.location
#   resource_group_name = azurerm_resource_group.spoke_1rg.name
#   size                  = "Standard_DS1_v2"
#   admin_username        = var.admin_username
#   admin_password        = var.admin_password
#   network_interface_ids = [azurerm_network_interface.nic[each.key].id]
 
#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }
  
 
#   source_image_reference {
#     publisher = "MicrosoftWindowsServer"
#     offer     = "WindowsServer"
#     sku       = "2019-Datacenter"
#     version   = "latest"
#   }
#   depends_on = [azurerm_resource_group.spoke_1rg, azurerm_network_interface.nic,azurerm_key_vault.Key_vault]
# }

# resource "azurerm_storage_account" "spoke_1storage-account" {
#   name                     = "storageaccount"
#   resource_group_name      = azurerm_resource_group.spoke_1rg.name
#   location                 = "East US"
#   account_tier             = "Standard"
#   account_replication_type = "LRS"

#   depends_on = [ azurerm_resource_group.spoke_1rg ]
# }
# resource "azurerm_storage_share" "spoke_1fileshare" {
#   name                 = "fileshare"
#   storage_account_name = azurerm_storage_account.spoke_1storage-account.name
#   quota                = 5
#   depends_on = [ azurerm_resource_group.spoke_1rg,azurerm_storage_account.spoke_1storage-account ]
# }

#route table for connect spoke1 and spoke2 through firewall
resource "azurerm_route_table" "spoke1-udr" {

  name = "spoke1-udr-to-firewall"
  location = azurerm_resource_group.spoke_1rg.location
  resource_group_name = azurerm_resource_group.spoke_1rg.name

  route {
    name = "route-to-firewall"
    address_prefix = "10.0.0.0/16"
    next_hop_type = "VirtualAppliance"
    next_hop_in_ip_address = "10.10.3.4"
  
  }
  
}

resource "azurerm_subnet_route_table_association" "spoke1udr_subnet_association" {
    for_each = var.subnets

    subnet_id = azurerm_subnet.subnets[each.key].id
    route_table_id = azurerm_route_table.spoke1-udr.id
    depends_on = [ azurerm_route_table.spoke1-udr,azurerm_subnet.subnets.id ]
}




 