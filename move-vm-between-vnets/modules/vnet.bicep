param location string = resourceGroup().location
param networkSecurityGroupName string
param securityRules array
param subnetName string
param subnetAddressPrefix string
param tags object
param vnetAddressPrefix string
param vnetName string

resource nsg 'Microsoft.Network/networkSecurityGroups@2020-06-01' = {
  name: networkSecurityGroupName
  location: location
  tags: tags
  properties: {
    securityRules: securityRules
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [ vnetAddressPrefix ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefixes: [ subnetAddressPrefix ]
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}
