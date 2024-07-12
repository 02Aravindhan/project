locals {
  subnet_name = [for i in azurerm_subnet.subnets : i.name]
}