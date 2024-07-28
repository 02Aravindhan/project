# PROJECT

![project](https://github.com/user-attachments/assets/fa1406bd-9083-4bbb-a393-b0024794705f)



HUB AND ONPREMISES NETWORK:

In the design of a robust Hub Virtual Network for hosting shared Azure services, it is essential to establish a central point of connectivity for cross-premises networks. This hub acts as the primary nexus for routing traffic between multiple virtual networks and on-premises environments. To ensure the security of outbound traffic, it is crucial to include a firewall within the hub network, which safeguards against potential threats and unauthorized access. Additionally, implementing a virtual network gateway is vital for enabling seamless and secure connectivity between on-premises systems and Azure resources. This gateway facilitates encrypted communication and ensures that data traversing between the on-premises network and the Azure environment remains protected and reliable.A Site-to-Site VPN gateway connection is used to connect your on-premises network to an Azure virtual network.
 
SPOKE_1 NETWORK:

 In the design of Spoke Virtual Networks, the primary objective is to isolate and manage workloads separately to enhance security and operational efficiency. Each spoke can be structured with multiple tiers and subnets, allowing for granular control and segmentation of different application components. Azure data disks should be attached to virtual machines (VMs) as required to ensure that persistent data storage is seamlessly integrated with VM operations. Additionally, at least one VM within each spoke must have a shared drive mounted using Azure File Share to facilitate centralized access to shared resources. For Spoke 01, it is imperative that it hosts a high-availability VM service, designed with multiple tiers and distributed workloads to ensure resilience and optimal performance. This configuration supports fault tolerance and load balancing, ensuring that critical services remain operational even in the face of potential disruptions.

SPOKE_2 NETWORK:

 In the configuration of Spoke 02, it is essential to ensure that it hosts a high-availability Virtual Machine Scale Set (VMSS) service to provide scalable and resilient application hosting. The VMSS should be designed to support Layer 7(application gateway) capabilities, enabling advanced application-layer traffic management and load balancing. Additionally, it must include SSL certificate termination to securely handle encrypted traffic and offload SSL decryption from backend instances. This setup ensures that traffic is efficiently managed and secured, contributing to both high availability and robust performance of applications hosted within this spoke.

SPOKE_3 NETWORK:
      
      
For Spoke 03, it is crucial to host at least one Azure App Service to facilitate the deployment and management of web applications and APIs. Azure App Service provides a fully managed platform that simplifies application development, scaling, and maintenance. By leveraging this service, you can deploy applications with high availability, automatic scaling, and built-in security features, allowing for efficient management and seamless integration with other Azure resources. This configuration ensures that applications hosted in Spoke 03 benefit from a reliable, scalable environment that supports continuous deployment and operational excellence.
  
VIRTUAL NETWORK PEERING  :

Connecting virtual networks within the same Azure region.