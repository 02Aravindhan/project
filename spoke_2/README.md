<!-- BEGIN_TF_DOCS -->
SPOKE\_2 RESOURCE GROUP:
    
 create to resource rroup including virtual networks  with subnets ,network security groups(use to rules.csv)  and virtual machine scale set,public ip, layer 7(application gateway) capabilities and SSL certificate,connect  the peering between spoke\_1 and spoke\_2. route table for connect spoke\_2 and spoke\_1 through firewall,subnet to route\_table\_association to established.

DIAGRAM:

 ![spoke\_2](https://github.com/user-attachments/assets/0898959a-0ac1-40d5-afcf-cedc2a091a38)

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

- [azurerm_application_gateway.spoke2-appgateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_gateway) (resource)
- [azurerm_network_security_group.spoke2-nsg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) (resource)
- [azurerm_public_ip.public-ip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) (resource)
- [azurerm_resource_group.spoke_2rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_route_table.spoke2-udr](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table) (resource)
- [azurerm_subnet.subnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet_route_table_association.spoke2udr_subnet_association](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_route_table_association) (resource)
- [azurerm_virtual_network.spoke2-vnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [azurerm_virtual_network_peering.Spoke_2-To-hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) (resource)
- [azurerm_virtual_network_peering.hub-To-Spoke-2](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) (resource)
- [azurerm_windows_virtual_machine_scale_set.vmss](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine_scale_set) (resource)
- [azurerm_key_vault.Key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) (data source)
- [azurerm_key_vault_secret.vm_admin_password](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) (data source)
- [azurerm_key_vault_secret.vm_admin_username](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) (data source)
- [azurerm_virtual_network.hub_vnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

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

### <a name="output_Spoke_2vnets"></a> [Spoke\_2vnets](#output\_Spoke\_2vnets)

Description: n/a

### <a name="output_public_ip"></a> [public\_ip](#output\_public\_ip)

Description: n/a

### <a name="output_spoke2-appgateway"></a> [spoke2-appgateway](#output\_spoke2-appgateway)

Description: n/a

### <a name="output_spoke_2rg"></a> [spoke\_2rg](#output\_spoke\_2rg)

Description: n/a

### <a name="output_subnets"></a> [subnets](#output\_subnets)

Description: n/a

## Modules

No modules.

<!-- END_TF_DOCS -->