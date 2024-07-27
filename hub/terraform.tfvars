resource_group_name = "hub-rg"
location  = "east asia"

vnets={
  "hub_vnets" = {
      vnet_name = "hub-vnets"
      address_space = "10.1.0.0/16"
    }
}

subnets = {
  
"AzureFirewallSubnet"={
            subnet_name="AzureFirewallSubnet"
            address_prefix="10.1.0.0/24"
        },
        "GatewaySubnet" = {
            subnet_name="GatewaySubnet"
            address_prefix="10.1.1.0/24"
            }
         } 
  