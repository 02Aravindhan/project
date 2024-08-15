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
  virtual_network_name = azurerm_virtual_network.hub-vnets["hub_vnets"].name
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

//Gateway
resource "azurerm_virtual_network_gateway" "hub-gateway" {
  name                = "hub-vpn-gateway"
  location            = azurerm_resource_group.hub-rg.location
  resource_group_name = azurerm_resource_group.hub-rg.name
 
  type     = "Vpn"
  vpn_type = "RouteBased"
  active_active = false
  
  sku           = "VpnGw1"
 
  ip_configuration {
    name                = "vnetGatewayConfig"
    public_ip_address_id = azurerm_public_ip.hub-public-ip["GatewaySubnet"].id

    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_subnet.subnets["GatewaySubnet"].id
  }
  depends_on = [ azurerm_resource_group.hub-rg , azurerm_public_ip.hub-public-ip , azurerm_subnet.subnets["GatewaySubnet"] ]
}


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
    public_ip_address_id = azurerm_public_ip.hub-public-ip["AzureFirewallSubnet"].id
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

resource "azurerm_firewall_policy_rule_collection_group" "icmp_rule" {

  name = "firewall-network-rule"
  firewall_policy_id = azurerm_firewall_policy.policy.id
  priority = 100

  # nat_rule_collection {          
  #   name     = "DNat-rule-collection"
  #   priority = 100
  #   action   = "dnat"

  #   rule {
  #     name             = "Allow-RDP"
  #     source_addresses = ["49.37.211.244"]   
  #     destination_ports = ["3389"]
  #     destination_address = azurerm_public_ip.hub-public-ip["AzureFirewallSubnet"].ip_address
  #     translated_address = "10.4.2.4"   
  #     translated_port    = "3389"
  #     protocols         = ["TCP"]
  #   }
  # }
 network_rule_collection {
    name     = "AllowICMP_Rules"
    priority = 100
     action       = "Deny"

    rule {
      name         = "AllowICMP"
      protocols = ["Any"]
      destination_ports = ["*"]
      source_addresses = ["10.0.0.0/16"]  
      destination_addresses = ["10.2.0.0/16"]
    }
  }
}


 
//  the data from onpremises Gateway Public_IP (IP_addr)

data "azurerm_public_ip" "Onpremises-VPN-GW-public-ip" {
 name = "public-ip"
  resource_group_name = "onpremises-rg"
}

//  the data from hub Virtual Network (address_space)

 data "azurerm_virtual_network" "onpremises-vnets" {
  name = "onpremises-vnets"
  resource_group_name = "onpremises-rg"
}


// Create the Local Network Gateway for VPN Gateway

resource "azurerm_local_network_gateway" "hub_local_gateway" {
  name                = "Hub-To-Onpremises"
  location            = azurerm_resource_group.hub-rg.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  gateway_address     = data.azurerm_public_ip.Onpremises-VPN-GW-public-ip.ip_address
  address_space       = [data.azurerm_virtual_network.onpremises-vnets.address_space[0]]
  depends_on = [ azurerm_public_ip.hub-public-ip , azurerm_virtual_network_gateway.hub-gateway ,
               data.azurerm_public_ip.Onpremises-VPN-GW-public-ip ,
                data.azurerm_virtual_network.onpremises-vnets ]
}
//Create the VPN-Connection for Connect the Networks
resource "azurerm_virtual_network_gateway_connection" "vpn_connection" {
  name                = "Hub-Onpremises-vpn-connect"
  location            = azurerm_resource_group.hub-rg.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  virtual_network_gateway_id     = azurerm_virtual_network_gateway.hub-gateway.id
  local_network_gateway_id       = azurerm_local_network_gateway.hub_local_gateway.id
  type                           = "IPsec"
  connection_protocol            = "IKEv2"
  shared_key                     = "SharedKey"

  depends_on = [ azurerm_resource_group.hub-rg,azurerm_virtual_network_gateway.hub-gateway , azurerm_local_network_gateway.hub_local_gateway]
}
