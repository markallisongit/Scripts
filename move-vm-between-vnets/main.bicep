@description('The admin password of the VM')
@secure()
param adminPassword string

@description('The admin user of the VM')
param adminUserName string

@description('Ip address whitelisted to the public endpoint')
@secure()
param allowedIp string

@description('Suffix to make deployment names unique')
param deploymentNameSuffix string = utcNow()

@description('Azure Region')
param location string = deployment().location

@description('Network security group name for subnet1 in vnet1.')
param nsg1Name string

@description('Network security group name for subnet1 in vnet2.')
param nsg2Name string

@description('Name of the resource group')
param resourceGroup string

@description('All resources should be tagged :)')
param tags object

@description('The size of the VM')
param vmSize string

@description('The Vnet to connect the VM to')
param vmVnet string

@description('The subnet to connect the VM to on deployment')
param vmSubnetName string = vnet1SubnetName

@description('Virtual network 1 IP address range.')
param vnet1AddressPrefix string

@description('Vnet1 name')
param vnet1Name string

@description('Name of the subnet for Vnet1')
param vnet1SubnetName string

@description('Address range for subnet in vnet1')
param vnet1SubnetPrefix string

@description('Virtual network 2 IP address range.')
param vnet2AddressPrefix string

@description('Vnet2 name')
param vnet2Name string

@description('Name of the subnet for Vnet2')
param vnet2SubnetName string

@description('Address range for subnet in vnet2')
param vnet2SubnetPrefix string


var vmName = toLower(uniqueString(subscription().id, rg.id, location))

// allow my public IP
var securityRules = [
  {
    name: 'let-me-in'
    properties: {
      priority: 1000
      sourceAddressPrefix: allowedIp
      protocol: 'Tcp'
      destinationPortRanges: [
        3389
      ]
      access: 'Allow'
      direction: 'Inbound'
      sourcePortRange: '*'
      destinationAddressPrefix: '*'
    }
  }
]

// create the resource group
targetScope = 'subscription'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroup
  location: location
  tags: tags
}

//  create vnet1
module vnet1 './modules/vnet.bicep' = {
  name: '${vnet1Name}.${deploymentNameSuffix}'
  params: {
    location: rg.location
    networkSecurityGroupName: nsg1Name
    securityRules: securityRules
    subnetName: vnet1SubnetName
    subnetAddressPrefix: vnet1SubnetPrefix
    tags: tags
    vnetAddressPrefix: vnet1AddressPrefix
    vnetName: vnet1Name    
  }
  scope: rg
}

//  create vnet2
module vnet2 './modules/vnet.bicep' = {
  name: '${vnet2Name}.${deploymentNameSuffix}'
  params: {
    location: rg.location
    networkSecurityGroupName: nsg2Name
    securityRules: securityRules
    subnetName: vnet2SubnetName
    subnetAddressPrefix: vnet2SubnetPrefix
    tags: tags
    vnetAddressPrefix: vnet2AddressPrefix
    vnetName: vnet2Name    
  }
  scope: rg
}

// create the vm connected to vnet1
module vm './modules/vm.bicep' = {
  name: '${vmName}.${deploymentNameSuffix}'
  params: {
    adminPassword: adminPassword
    adminUserName: adminUserName
    location: location
    osDiskType: 'Standard_LRS'
    subnetName: vmSubnetName
    tags: tags
    vmName: vmName
    vmSize: vmSize
    vnetName: vmVnet
    vnetResourceGroup: resourceGroup
    pipSku: 'Basic'
  }
  scope: rg
  dependsOn: [
    vnet1
  ]
}

output vmName string = vmName
