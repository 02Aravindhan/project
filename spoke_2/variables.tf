variable "resource_group_name"{
    type=string
    default = "spoke_2rg"
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
        address_space="10.3.0.0/16"
        vnetname="spoke2-vnets"
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
            address_prefix="10.3.1.0/24"
            },
         "subnet2"={
            subnetname="subnet2"
            address_prefix="10.3.2.0/24"
         }  
      }
}
variable "rules_file" {
    type = string
    default = "rules.csv"
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
