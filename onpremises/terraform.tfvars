resource_group_name = "onpremises-rg"
location  = "east asia"

vnets={
  "onpremises-vnets" = {
      vnet_name = "onpremises-vnets"
      address_space = "10.0.0.0/16"
    }
}

subnets = {
  
         "GatewaySubnet" = {
            subnet_name="GatewaySubnet"
            address_prefix="10.0.1.0/24"
            },
         "subnet"={
            subnet_name="subnet"
            address_prefix="10.0.2.0/24"
         }  
      }
        
admin_username = "mass"
admin_password = "aravindhan123@"

  