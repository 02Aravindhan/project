<!-- BEGIN_TF_DOCS -->
ONPREMISES RESOURCE GROUP:

 create to resource groups including virtual networks  with subnets and  virtual network gateway,vpn connection, the Local Network     Gateway and Connection service for establish the connection between Onpremises and hub.

 DIAGRAM:
    
   ![onpremises1](https://github.com/user-attachments/assets/2d405d36-881f-4fce-80f8-619c990c115b)

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
  name                        = "KeyVault4648"
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
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.1.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 3.0.2)

## Providers

The following providers are used by this module:

- <a name="provider_azuread"></a> [azuread](#provider\_azuread)

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (~> 3.0.2)

## Resources

The following resources are used by this module:

- [azurerm_key_vault.Key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) (resource)
- [azurerm_key_vault_secret.vm_admin_password](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) (resource)
- [azurerm_key_vault_secret.vm_admin_username](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) (resource)
- [azurerm_local_network_gateway.OnPremises_local_gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/local_network_gateway) (resource)
- [azurerm_network_interface.onpremises-nic](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) (resource)
- [azurerm_public_ip.onpremises-ip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) (resource)
- [azurerm_resource_group.onpremises-rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_route_table.onpremises-udr-spoke1](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table) (resource)
- [azurerm_subnet.subnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet_route_table_association.routetable--Associate](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_route_table_association) (resource)
- [azurerm_virtual_network.onpremises-vnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [azurerm_virtual_network_gateway.onpremises-gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway) (resource)
- [azurerm_virtual_network_gateway_connection.vpn_connection](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway_connection) (resource)
- [azurerm_windows_virtual_machine.onpremises-vm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine) (resource)
- [azuread_client_config.current](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/client_config) (data source)
- [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) (data source)
- [azurerm_public_ip.Hub-VPN-GW-public-ip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/public_ip) (data source)
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

No optional inputs.

## Outputs

The following outputs are exported:

### <a name="output_OnPremise-rg"></a> [OnPremise-rg](#output\_OnPremise-rg)

Description: n/a

### <a name="output_onpremises-Gateway"></a> [onpremises-Gateway](#output\_onpremises-Gateway)

Description: n/a

### <a name="output_onpremises-ip"></a> [onpremises-ip](#output\_onpremises-ip)

Description: n/a

### <a name="output_onpremises-vm"></a> [onpremises-vm](#output\_onpremises-vm)

Description: n/a

### <a name="output_onpremises-vnets"></a> [onpremises-vnets](#output\_onpremises-vnets)

Description: n/a

### <a name="output_subnets"></a> [subnets](#output\_subnets)

Description: n/a

## Modules

No modules.

<!-- END_TF_DOCS -->