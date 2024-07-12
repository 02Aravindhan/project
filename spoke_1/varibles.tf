
variable "resource_group_name"{
    type=string
    default = "spoke_1rg"
}
variable "location" {
    type = string
    default = "east asia"
  
}
variable "vnets" {
  type = map(object({
    address_space = string
    vnetname=string
    
  }))
  default = {
    "vnets" = {
        address_space="10.2.0.0/16"
        vnetname="spoke1-vnet"
        }
  }

}
variable "subnets" {
    type = map(object({
      subnetname =string
      address_prefix=string
      }))
      default = {
        "Subnet1" = {
            subnetname="Subnet1"
            address_prefix="10.2.1.0/24"
            },
         "subnet2"={
            subnetname="subnet2"
            address_prefix="10.2.2.0/24"
         }  
      }
}
variable "admin_username"{
    type=string
    default = "mass"
}
variable "admin_password" {
    type = string
    default = "aravindhan123@"
    sensitive =true
  
}
