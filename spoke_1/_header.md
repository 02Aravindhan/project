SPOKE_1 RESOURCE GROUP:

 create to resource group including virtual networks  with subnets and network security groups,one spoke must host a high-availability virtual machine service.VM  have a shared drive mounted using Azure File Share, the Azure Key valut service to store the virtual machine to username and password. connect  the peering between hub and Spoke_1. route table for connect spoke1 and spoke2 through firewall,subnet to route_table_association to established.

 DIAGRAM:


  ![spoke_1](https://github.com/user-attachments/assets/0260d4f1-c224-4b31-a756-b89b67659694)

### Apply the Terraform configurations :

  Deploy the resources using Terraform,
```
terraform init
```
```
terraform plan
```
```
terraform apply
```