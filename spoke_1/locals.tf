locals{
  subnetname= [for i in azurerm_subnet.subnets : i.name]
}  
# [
#   "Subnet1",
#   "subnet2",
# ]
# > toset([for i in azurerm_subnet.subnets : i.name])
# toset([
#   "Subnet1",
#   "subnet2",
# ])


# for_each = toset(local.subnetname)
#   name                  = "${each.key}-vm"