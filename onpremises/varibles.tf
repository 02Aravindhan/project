variable "resource_group_name"{
    type=string
    default = "onpremises-rg"
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
        address_space="10.0.0.0/16"
        vnetname="onpremises-vnet"
        }
  }

}
variable "subnets" {
    type = map(object({
      subnetname =string
      address_prefix=string
      }))
      default = {
        "GatewaySubnet" = {
            subnetname="GatewaySubnet"
            address_prefix="10.0.1.0/24"
            },
         "subnet"={
            subnetname="subnet"
            address_prefix="10.0.2.0/24"
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
