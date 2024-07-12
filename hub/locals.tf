locals{
  subnetname= [for i in azurerm_subnet.subnets : i.name]
} 