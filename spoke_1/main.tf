
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
  virtual_network_name = azurerm_virtual_network.spoke_1vnets["spoke_1vnets"].name
}

//spoke-1 nic
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
# key vault
data "azurerm_key_vault" "Key_vault" {
  name                = "KeyVault4646"
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


#Create the Network Security Group with Rules
resource "azurerm_network_security_group" "spoke_1nsg" {
  for_each = toset(local.subnet_names)
  name = each.key
  resource_group_name = azurerm_resource_group.spoke_1rg.name
  location = azurerm_resource_group.spoke_1rg.location

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
  depends_on = [ azurerm_resource_group.spoke_1rg,azurerm_subnet.subnets ]
  
}


//spoke_1 vm 

  resource "azurerm_windows_virtual_machine" "spoke_1vm" {
  for_each = toset(local.subnet_names)
  name                  = "${each.key}-vm"
  location            = azurerm_resource_group.spoke_1rg.location
  resource_group_name = azurerm_resource_group.spoke_1rg.name
  size                  = "Standard_DS1_v2"
  admin_username        = data.azurerm_key_vault_secret.vm_admin_username.value
  admin_password        = data.azurerm_key_vault_secret.vm_admin_password.value
  network_interface_ids = [azurerm_network_interface.spoke-1nic[each.key].id]
 
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
  depends_on = [azurerm_resource_group.spoke_1rg,azurerm_network_interface.spoke-1nic ,data.azurerm_key_vault.Key_vault]
}

//storage-account

resource "azurerm_storage_account" "spoke_1storage-account" {
  name                     = "aravindstacc46461"
  resource_group_name      = azurerm_resource_group.spoke_1rg.name
  location                 = "East US"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  depends_on = [ azurerm_resource_group.spoke_1rg ]
}

//fileshare

resource "azurerm_storage_share" "spoke_1fileshare" {
  name                 = "fileshare"
  storage_account_name = azurerm_storage_account.spoke_1storage-account.name
  quota                = 5
  depends_on = [ azurerm_resource_group.spoke_1rg,azurerm_storage_account.spoke_1storage-account ]
}

# # Mount the fileshare to Vitrual Machine
# resource "azurerm_virtual_machine_extension" "extension" {
#   name                 = "vm-extension"
#   virtual_machine_id   = azurerm_windows_virtual_machine.spoke_1vm.id
#   publisher            = "Microsoft.Compute"
#   type                 = "CustomScriptExtension"
#   type_handler_version = "1.9"

#   protected_settings = <<SETTINGS
#   {
#    "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${local.base64EncodedScript }')) | Out-File -filepath postBuild.ps1\" && powershell -ExecutionPolicy Unrestricted -File postBuild.ps1"
#   }
#   SETTINGS

#   depends_on = [azurerm_windows_virtual_machine.spoke_1vm]
# }


//route table for connect spoke1 and spoke2 through firewall

resource "azurerm_route_table" "spoke1-udr" {

  name = "spoke1-udr-to-firewall"
  location = azurerm_resource_group.spoke_1rg.location
  resource_group_name = azurerm_resource_group.spoke_1rg.name

  route {
    name = "route-to-firewall"
    address_prefix = "10.2.0.0/16"       //spoke_1ip
    next_hop_type = "VirtualAppliance"
    next_hop_in_ip_address = "10.1.0.4"     //firewall ip
  
  }
  depends_on = [ azurerm_resource_group.spoke_1rg ]
}

   
# //spoke_1udr subnet assocate

resource "azurerm_subnet_route_table_association" "spoke1udr_subnet_association" {
    for_each = var.subnets

    subnet_id = azurerm_subnet.subnets[each.key].id
    route_table_id = azurerm_route_table.spoke1-udr.id
    depends_on = [ azurerm_route_table.spoke1-udr ]
}

 # connect the data from Hub Vnet for peering the Spoke_1 Vnet 
data "azurerm_virtual_network" "hub_vnets" {
  name = "hub_vnets"
  resource_group_name = "hub-rg"
}

 # Establish the Peering between Spoke_1 and Hub networks (Spoke_1 <--> Hub)
resource "azurerm_virtual_network_peering" "Spoke_1-To-hub" {
  name                      = "Spoke_1-To-hub"
  resource_group_name       = azurerm_resource_group.spoke_1rg.name
  virtual_network_name      = azurerm_virtual_network.spoke_1vnets["spoke_1vnets"].name
  remote_virtual_network_id = data.azurerm_virtual_network.hub_vnets.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.spoke_1vnets , data.azurerm_virtual_network.hub_vnets  ]
}
# Establish the Peering between  Hub and Spoke_1 networks (Hub <--> Spoke_1)
resource "azurerm_virtual_network_peering" "hub-To-Spoke-1" {
  name                      = "hub-To-Spoke_1"
  resource_group_name       = data.azurerm_virtual_network.hub_vnets.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.hub_vnets.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_1vnets["spoke_1vnets"].id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.spoke_1vnets , data.azurerm_virtual_network.hub_vnets ]
}







 