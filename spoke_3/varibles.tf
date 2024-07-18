
variable "resource_group_name"{
    type=string
    default = "spoke_3rg"
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
        address_space="10.4.0.0/16"
        vnetname="spoke-3vnet"
        }
  }

}
variable "subnets" {
    type = map(object({
      subnetname =string
      address_prefix=string
      }))
      default = {
        "AppServiceSubnet" = {
            subnetname="AppServiceSubnet"
            address_prefix="10.4.1.0/24"
            }
        
      }
}
