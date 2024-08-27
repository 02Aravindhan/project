<!-- BEGIN_TF_DOCS -->
SPOKE\_1 RESOURCE GROUP:

 create to resource group including virtual networks  with subnets and network security groups,one spoke must host a high-availability virtual machine service.VM  have a shared drive mounted using Azure File Share, the Azure Key valut service to store the virtual machine to username and password. connect  the peering between hub and Spoke\_1. route table for connect spoke1 and spoke2 through firewall,subnet to route\_table\_association to established.

 DIAGRAM:

  ![spoke_1](https://github.com/user-attachments/assets/77bee6d5-b2ef-4649-947b-ee52a8db638f)

### Apply the Terraform configurations :

  Deploy the resources using Terraform,
```
terraform init
```
```
terraform plan
```
```
terraform apply
```

```hcl

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







 
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.1.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 3.0.2)

## Providers

The following providers are used by this module:

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (~> 3.0.2)

## Resources

The following resources are used by this module:

- [azurerm_network_interface.spoke-1nic](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) (resource)
- [azurerm_network_security_group.spoke_1nsg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) (resource)
- [azurerm_resource_group.spoke_1rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_route_table.spoke1-udr](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table) (resource)
- [azurerm_storage_account.spoke_1storage-account](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) (resource)
- [azurerm_storage_share.spoke_1fileshare](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_share) (resource)
- [azurerm_subnet.subnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet_route_table_association.spoke1udr_subnet_association](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_route_table_association) (resource)
- [azurerm_virtual_network.spoke_1vnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [azurerm_virtual_network_peering.Spoke_1-To-hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) (resource)
- [azurerm_virtual_network_peering.hub-To-Spoke-1](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) (resource)
- [azurerm_windows_virtual_machine.spoke_1vm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine) (resource)
- [azurerm_key_vault.Key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) (data source)
- [azurerm_key_vault_secret.vm_admin_password](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) (data source)
- [azurerm_key_vault_secret.vm_admin_username](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) (data source)
- [azurerm_virtual_network.hub_vnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password)

Description: The Password of the User

Type: `string`

### <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username)

Description: The Username of the User

Type: `string`

### <a name="input_location"></a> [location](#input\_location)

Description: The Location of the Resource Group

Type: `string`

### <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name)

Description: The name of the Resource Group

Type: `string`

### <a name="input_subnets"></a> [subnets](#input\_subnets)

Description: The details of the Subnets

Type:

```hcl
map(object({
    subnet_name = string
    address_prefix = string
  }))
```

### <a name="input_vnets"></a> [vnets](#input\_vnets)

Description: The details of the VNET

Type:

```hcl
map(object({
    vnet_name = string
    address_space = string
  }))
```

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_rules_file"></a> [rules\_file](#input\_rules\_file)

Description: The name of CSV file containing NSG rules

Type: `string`

Default: `"rules.csv"`

## Outputs

The following outputs are exported:

### <a name="output_Spoke_1vnet"></a> [Spoke\_1vnet](#output\_Spoke\_1vnet)

Description: n/a

### <a name="output_fileshare"></a> [fileshare](#output\_fileshare)

Description: n/a

### <a name="output_spoke_1rg"></a> [spoke\_1rg](#output\_spoke\_1rg)

Description: n/a

### <a name="output_spoke_1vm"></a> [spoke\_1vm](#output\_spoke\_1vm)

Description: n/a

### <a name="output_subnets"></a> [subnets](#output\_subnets)

Description: n/a

## Modules

No modules.

<!-- END_TF_DOCS -->