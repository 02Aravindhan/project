locals {
    rules_csv = csvdecode(file(var.rules_file))
    subnet_names = [for subnet in azurerm_subnet.subnets : subnet.name]
}