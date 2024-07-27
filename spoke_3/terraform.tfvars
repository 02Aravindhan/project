resource_group_name = "spoke-3rg"
location  = "east asia"

vnets={
  "spoke-3vnets" = {
      vnet_name = "spoke-3vnets"
      address_space = "10.4.0.0/16"
    }
}

subnets = {
  
 "AppServiceSubnet" = {
             subnet_name="AppServiceSubnet"
            address_prefix="10.4.1.0/24"
             }
        
       }
 