locals {
    rules = csvdecode(file(var.rules_file))
    subnet_names = [for subnet in azurerm_subnet.subnets : subnet.name]
    app_gateway_backend_address_id= [for pool in azurerm_application_gateway.spoke2-appgateway.backend_address_pool : pool.id]
       #[
           #"/subscriptions/27785a28-d8bf-4fe6-8295-5f7bbbc85a88/resourceGroups/spoke_2rg/providers/Microsoft.Network/applicationGateways/spoke2-appgateway/backendAddressPools/appGatewayBackendPool",
       #]

}