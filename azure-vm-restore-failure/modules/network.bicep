@description('The network location')
param location string = resourceGroup().location

@description('Network security group name.')
param networkSecurityGroupName string

@description('Security rules')
param securityRules array

@description('Name of the subnet')
param subnetName string

@description('Name of the subnet')
param subnetAddressRange string

@description('All resources should be tagged.')
param tags object

@description('Virtual network IP address range.')
param vnetAddressRange string

@description('Vnet name')
param vnetName string

resource nsg 'Microsoft.Network/networkSecurityGroups@2020-06-01' = {
  name: networkSecurityGroupName
  location: location
  tags: tags
  properties: {
    securityRules: securityRules
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressRange
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressRange
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}
