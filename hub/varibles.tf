variable "resource_group_name"{
    type=string
    default = "hub-rg"
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
        address_space="10.1.0.0/16"
        vnetname="hub-vnet"
        }
  }

}
variable "subnets" {
    type = map(object({
      subnetname =string
      address_prefix=string
      }))
      default = {
        "AzureFireWallSubnet"={
            subnetname="AzureFireWallSubnet"
            address_prefix="10.1.0.0/24"
        },
        "GatewaySubnet" = {
            subnetname="GatewaySubnet"
            address_prefix="10.1.1.0/24"
            },
         "subnet"={
            subnetname="subnet"
            address_prefix="10.1.2.0/24"
         }  
      }

  
}