<!-- BEGIN_TF_DOCS -->
SPOKE\_3 RESOURCE GROUP:

create to  resource group including  the virtual network with subnet , App service and app service plan.connect to the peering between spoke\_3 and hub.

DIAGRAM:

 ![spoke\_3](https://github.com/user-attachments/assets/a14a5dec-8fe0-4f5b-b0b8-5d4d64f5e7ec)

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
resource "azurerm_resource_group" "spoke-3rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "spoke-3vnets" {
  for_each = var.vnets

  name                = each.key
  address_space       = [each.value.address_space]
  location            = azurerm_resource_group.spoke-3rg.location
  resource_group_name = azurerm_resource_group.spoke-3rg.name
  depends_on          = [azurerm_resource_group.spoke-3rg]
 }


resource "azurerm_subnet" "AppServiceSubnet" {
  for_each = var.subnets

  name   = each.key
  address_prefixes =[each.value.address_prefix]
  resource_group_name = azurerm_resource_group.spoke-3rg.name
  depends_on = [ azurerm_resource_group.spoke-3rg , azurerm_virtual_network.spoke-3vnets]
  virtual_network_name = azurerm_virtual_network.spoke-3vnets["spoke-3vnets"].name
   delegation {
    name = "appservice_delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }
}

//app_service_plan
resource "azurerm_app_service_plan" "spoke-3plan" {
  name                = "app-service-plan"
  resource_group_name =azurerm_resource_group.spoke-3rg.name 
  location = azurerm_resource_group.spoke-3rg.location
  
  sku {
    tier = "Basic"   
    size = "B1"      
  }
  depends_on = [ azurerm_resource_group.spoke-3rg ]
 }

//app_service

resource "azurerm_app_service" "spoke-3app-services" {
  name                = "sp3-appservice"  
  location            =azurerm_resource_group.spoke-3rg.location          
  resource_group_name = azurerm_resource_group.spoke-3rg.name  

  app_service_plan_id = azurerm_app_service_plan.spoke-3plan.id 
  
  depends_on = [ azurerm_resource_group.spoke-3rg,azurerm_app_service_plan.spoke-3plan ]
  
}

# integrate to hub
resource "azurerm_app_service_virtual_network_swift_connection" "vnet-integration" {
  app_service_id = azurerm_app_service.spoke-3app-services.id
  subnet_id = azurerm_subnet.AppServiceSubnet["AppServiceSubnet"].id
  depends_on = [ azurerm_app_service.spoke-3app-services , azurerm_subnet.AppServiceSubnet ]
}


 #  connect to hub(Spoke-3 <--> Hub)

data "azurerm_virtual_network" "hub_vnets" {
  name ="hub_vnets"
  resource_group_name = "hub-rg"
}

# connect to peering spoke3 to hub (Spoke3 <--> hub)
resource "azurerm_virtual_network_peering" "Spoke3-To-hub" {
  name                      = "Spoke3-To-hub"
  resource_group_name       = azurerm_resource_group.spoke-3rg.name
  virtual_network_name      = azurerm_virtual_network.spoke-3vnets["spoke-3vnets"].name
  remote_virtual_network_id = data.azurerm_virtual_network.hub_vnets.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.spoke-3vnets , data.azurerm_virtual_network.hub_vnets  ]
}

#connectto peering hub to spoke3(hub <--> Spoke3)
resource "azurerm_virtual_network_peering" "hub-To-Spoke3" {
  name                      = "hub-Spoke3"
  resource_group_name       = data.azurerm_virtual_network.hub_vnets.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.hub_vnets.name
  remote_virtual_network_id = azurerm_virtual_network.spoke-3vnets["spoke-3vnets"].id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.spoke-3vnets , data.azurerm_virtual_network.hub_vnets ]
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

- [azurerm_app_service.spoke-3app-services](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service) (resource)
- [azurerm_app_service_plan.spoke-3plan](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_plan) (resource)
- [azurerm_app_service_virtual_network_swift_connection.vnet-integration](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_virtual_network_swift_connection) (resource)
- [azurerm_resource_group.spoke-3rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.AppServiceSubnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_virtual_network.spoke-3vnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [azurerm_virtual_network_peering.Spoke3-To-hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) (resource)
- [azurerm_virtual_network_peering.hub-To-Spoke3](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) (resource)
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

No optional inputs.

## Outputs

The following outputs are exported:

### <a name="output_Spoke-3rg"></a> [Spoke-3rg](#output\_Spoke-3rg)

Description: n/a

### <a name="output_app_plan"></a> [app\_plan](#output\_app\_plan)

Description: n/a

### <a name="output_sp3-appservice"></a> [sp3-appservice](#output\_sp3-appservice)

Description: n/a

### <a name="output_vnets"></a> [vnets](#output\_vnets)

Description: n/a

## Modules

No modules.

<!-- END_TF_DOCS -->