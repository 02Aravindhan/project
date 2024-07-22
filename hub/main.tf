resource "azurerm_resource_group" "hub-rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "hub-vnets" {
  for_each = var.vnets

  name                = each.key
  address_space       = [each.value.address_space]
  location            = azurerm_resource_group.hub-rg.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  depends_on          = [azurerm_resource_group.hub-rg]
}
resource "azurerm_subnet" "subnets" {
  for_each = var.subnets

  name   = each.key
  address_prefixes =[each.value.address_prefix]
  resource_group_name = azurerm_resource_group.hub-rg.name
  depends_on = [ azurerm_resource_group.hub-rg , azurerm_virtual_network.hub-vnets]
  virtual_network_name = azurerm_virtual_network.hub-vnets["vnets"].name
}
resource "azurerm_public_ip" "hub-public-ip" {
  for_each = toset(local.subnetname)
  name = "${each.key}-IP"
  location            = azurerm_resource_group.hub-rg.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on = [ azurerm_resource_group.hub-rg ]
}

# resource "azurerm_virtual_network_gateway" "hub-gateway" {
#   name                = "hub-vpn-gateway"
#   location            = azurerm_resource_group.hub-rg.location
#   resource_group_name = azurerm_resource_group.hub-rg.name
 
#   type     = "Vpn"
#   vpn_type = "RouteBased"
#   active_active = false
  
#   sku           = "VpnGw1"
 
#   ip_configuration {
#     name                = "vnetGatewayConfig"
#     public_ip_address_id = azurerm_public_ip.hub-public-ip["Gatewaysubnet"].id

#     private_ip_address_allocation = "Dynamic"
#     subnet_id = azurerm_subnet.subnets["GatewaySubnet"].id
#   }
#   depends_on = [ azurerm_resource_group.hub-rg , azurerm_public_ip.hub-public-ip , azurerm_subnet.subnets["GatewaySubnet"] ]
# }


//firewall 
resource "azurerm_firewall" "hub-firewall" {
  name                = "firewall"
  location            = azurerm_resource_group.hub-rg.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  sku_name       = "AZFW_VNet"  # Specify the SKU here
  sku_tier = "Standard"
  ip_configuration {
    name                 = "Firewallconfiguration"
 subnet_id = azurerm_subnet.subnets["AzureFirewallSubnet"].id
    public_ip_address_id = azurerm_public_ip.hub-public-ip["AzureFireWallSubnet"].id
  }
  depends_on = [ azurerm_resource_group.hub-rg,azurerm_public_ip.hub-public-ip,azurerm_subnet.subnets ]
  }

#firewall policy
resource "azurerm_firewall_policy" "policy" {
  name                = "firewall-policy"
  resource_group_name = azurerm_resource_group.hub-rg.name
  location            = azurerm_resource_group.hub-rg.location

  base_policy_id      = null
  
}
#firewall rule

resource "azurerm_firewall_policy_rule_collection_group" "firewall_ policy_rule" {

  name = "firewall-network-rule"
  firewall_policy_id = azurerm_firewall_policy.policy.id
  priority = 100
 network_rule_collection {
    name     = "AllowICMP_Rules"
    priority = 100
     action       = "Deny"

    rule {
      name         = "AllowICMP"
      protocols = ["ICMP"]
      destination_ports = ["80"]
      source_addresses = ["10.2.0.0/16"]  
      destination_addresses = ["10.3.0.0/16"]
    }
  }
}


 
//  the data from onpremises Gateway Public_IP (IP_addr)

# data "azurerm_public_ip" "onpremises-VPN-GW-public-ip" {
#  name = "GatewaySubnet-IP"
#   resource_group_name = "onpremises-rg"
# }

//  the data from hub Virtual Network (address_space)

# data "azurerm_virtual_network" "onpremises-vnets" {
#   name = "onpremises-vnet"
#   resource_group_name = "onpremises-rg"
# }


// Create the Local Network Gateway for VPN Gateway

# resource "azurerm_local_network_gateway" "hub_local_gateway" {
#   name                = "Hub-To-Onpremises"
#   location            = azurerm_resource_group.hub-rg.location
#   resource_group_name = azurerm_resource_group.hub-rg.name
#   gateway_address     = data.azurerm_public_ip.Onpremises-VPN-GW-public-ip.ip_address
#   address_space       = [data.azurerm_virtual_network.onpremises-vnets.address_space]
#   depends_on = [ azurerm_public_ip.hub-public-ip , azurerm_virtual_network_gateway.hub-gateway ,
#                data.azurerm_public_ip.onpremises-VPN-GW-public-ip ,
#                 data.azurerm_virtual_network.onpremises-vnets ]
# }
# # Create the VPN-Connection for Connect the Networks
# resource "azurerm_virtual_network_gateway_connection" "vpn_connection" {
#   name                = "Hub-Onpremises-vpn-connect"
#   location            = azurerm_resource_group.hub-rg.location
#   resource_group_name = azurerm_resource_group.hub-rg.name
#   virtual_network_gateway_id     = azurerm_virtual_network_gateway.hub-gateway.id
#   local_network_gateway_id       = azurerm_local_network_gateway.hub_local_gateway.id
#   type                           = "IPsec"
#   connection_protocol            = "IKEv2"
#   shared_key                     = "SharedKey"

#   depends_on = [ azurerm_resource_group.hub-rg,azurerm_virtual_network_gateway.hub-gateway , azurerm_local_network_gateway.hub_local_gateway]

# connect the data from spoke_1 Vnet for peering the hub Vnet (hub<--> spoke_1)
data "azurerm_virtual_network" "spoke_1vnets" {
  name = "spoke_1vnet"
  resource_group_name = "spoke_1rg"
}

# Establish the Peering between hub and  spoke_1 networks (hub <--> spoke_1)
resource "azurerm_virtual_network_peering" "hub-To-spoke_1" {
  name                      = "hub-To-spoke_1"
  resource_group_name       = azurerm_resource_group.hub-rg.name
  virtual_network_name      = azurerm_virtual_network.hub-vnets.name
  remote_virtual_network_id = data.azurerm_virtual_network.spoke_1vnets.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.hub-vnets , data.azurerm_virtual_network.spoke_1vnets  ]
}
# Establish the Peering between  spoke_1 and hub networks (spoke_1 <--> hub)
resource "azurerm_virtual_network_peering" "spoke_1-To-hub" {
  name                      = "spoke_1-To-hub"
  resource_group_name       = data.azurerm_virtual_network.spoke_1vnets.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.spoke_1vnets.name
  remote_virtual_network_id = azurerm_virtual_network.hub-vnets.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.hub-vnets , data.azurerm_virtual_network.spoke_1vnets ]
}

# connect the data from spoke_2 Vnet for peering the hub Vnet (hub <--> spoke_2)
data "azurerm_virtual_network" "spoke2-vnet" {
  name = "spoke2-vnet"
  resource_group_name = "spoke_2rg"
}

# connect the Peering between Spoke_2 and Hub networks (Spoke_2 <--> Hub)
resource "azurerm_virtual_network_peering" "spoke2-To-hub" {
  name                      = "Spoke_2-To-hub"
  resource_group_name       = azurerm_resource_group.spoke_2rg.name
  virtual_network_name      = azurerm_virtual_network.spoke2-vnet.name
  remote_virtual_network_id = data.azurerm_virtual_network.hub_vnets.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.spoke2-vnet , data.azurerm_virtual_network.hub_vnets  ]
}
# connect the Peering between  Hub and Spoke_2 networks (Hub <--> Spoke_2)
resource "azurerm_virtual_network_peering" "hub-To-Spoke2" {
  name                      = "hub-To-Spoke_2"
  resource_group_name       = data.azurerm_virtual_network.hub_vnets.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.hub_vnets.name
  remote_virtual_network_id = azurerm_virtual_network.spoke2-vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.spoke2-vnet , data.azurerm_virtual_network.hub_vnets ]
}

# connect the data from spoke_3 Vnet for peering the hub Vnet (hub <--> spoke_3)
data "azurerm_virtual_network" "spoke-3vnets" {
  name = "spoke-3vnets"
  resource_group_name = "spoke-3rg"
}

# connect the Peering between Spoke_3 and Hub networks (Spoke_3 <--> Hub)
resource "azurerm_virtual_network_peering" "Spoke_3-To-hub" {
  name                      = "Spoke_3-To-hub"
  resource_group_name       = azurerm_resource_group.spoke-3rg.name
  virtual_network_name      = azurerm_virtual_network.spoke-3vnets.name
  remote_virtual_network_id = data.azurerm_virtual_network.hub_vnets.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.spoke-3vnetst , data.azurerm_virtual_network.hub_vnets  ]
}
# connect the Peering between  Hub and Spoke_3 networks (Hub <--> Spoke_3)
resource "azurerm_virtual_network_peering" "hub-To-Spoke_3" {
  name                      = "hub-To-Spoke_3"
  resource_group_name       = data.azurerm_virtual_network.hub_vnets.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.hub_vnets.name
  remote_virtual_network_id = azurerm_virtual_network.spoke-3vnets.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.spoke-3vnets , data.azurerm_virtual_network.hub_vnets ]
}

