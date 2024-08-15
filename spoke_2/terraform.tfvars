resource_group_name = "spoke_2rg"
location  = "east asia"

vnets={
  "spoke2-vnets" = {
      vnet_name = "spoke2-vnets"
      address_space = "10.3.0.0/16"
    }
}

subnets = {
     "Subnet1" = {
            subnet_name="Subnet1"
            address_prefix="10.3.1.0/24"
            },
         "subnet2"={
            subnet_name="subnet2"
            address_prefix="10.3.2.0/24"
         }  
      }

  
       

        

