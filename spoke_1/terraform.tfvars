resource_group_name = "spoke_1rg"
location  = "east asia"

vnets={
  "spoke_1vnets" = {
      vnet_name = "spoke_1vnets"
      address_space = "10.2.0.0/16"
    }
}

subnets = {
  
        "Subnet1" = {
            subnetname="Subnet1"
            address_prefix="10.2.1.0/24"
            },
         "subnet2"={
            subnetname="subnet2"
            address_prefix="10.2.2.0/24"
         }  
      }

        
admin_username = "mass"
admin_password = "aravindhan123@"

rules_file = "rules"