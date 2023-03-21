@description('The network location')
param location string = resourceGroup().location

@description('Managed Instance Network security group name.')
param sqlmiNetworkSecurityGroupName string

@description('Name of the Managed Instance subnet route table')
param sqlmiRouteTableName string

@description('SQLMI subnet Security rules')
param sqlmiSecurityRules array

@description('MI subnet address IP range.')
param sqlmiSubnetAddressRange string

@description('vm Network security group name.')
param vmNetworkSecurityGroupName string

@description('VM subnet Security rules')
param vmSecurityRules array

@description('MI subnet address IP range.')
param vmSubnetAddressRange string

@description('Name of the subnet for the VM.')
param vmSubnetName string = 'vm-subnet'

@description('Virtual network IP address range.')
param vnetAddressRange string

@description('Vnet name')
param vnetName string

@description('All resources should be tagged.')
param tags object

// load the network intent policy routes that were exported from ExportNetworkPolicy.ps1
var policySecurityRules = json(loadTextContent('../network-intent-policy-rules.json'))

// load the network intent policy rules that were exported from ExportNetworkPolicy.ps1
var policyRoutes = json(loadTextContent('../network-intent-policy-routes.json'))

var nsgConfigs = [
  {
    name: sqlmiNetworkSecurityGroupName
    securityRules: union(policySecurityRules, sqlmiSecurityRules)
  }
  {
    name: vmNetworkSecurityGroupName
    securityRules: vmSecurityRules
  }
]

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-09-01' = [for n in nsgConfigs: {
  name: n.name
  location: location
  tags: tags
  properties: {
    securityRules: n.securityRules
  }
}]

resource rt 'Microsoft.Network/routeTables@2022-09-01' =  {
  name: sqlmiRouteTableName
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: policyRoutes
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-09-01' = {
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
        name: 'ManagedInstance'
        properties: {
          addressPrefix: sqlmiSubnetAddressRange
          routeTable: {
            id: rt.id
          }
          networkSecurityGroup: {
            id: nsg[0].id
          }
          delegations: [
            {
              name: 'managedInstanceDelegation'
              properties: {
                serviceName: 'Microsoft.Sql/managedInstances'
              }
            }
          ]
        }
      }
      {
        name: vmSubnetName
        properties: {
          addressPrefix: vmSubnetAddressRange
          networkSecurityGroup: {
            id: nsg[1].id
          }
        }
      }
    ]
  }
}
