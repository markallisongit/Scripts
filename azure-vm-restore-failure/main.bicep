@description('The admin password')
@secure()
param adminPassword string

@description('The admin user')
param adminUserName string

@description('Ip address whitelisted to the public endpoint')
param allowedIp string

@description('Number of backup retention days')
param dailyRetentionDurationCount int

@description('Backup will run on array of Days like, Monday, Tuesday etc. Applies in Weekly retention only.')
param daysOfTheWeek array

@description('Number of weeks you want to retain the backup')
param weeklyRetentionDurationCount int

@description('Number of months you want to retain the backup')
param monthlyRetentionDurationCount int

@description('Enable cross region restore')
param enablecrossRegionRestore bool = true

@description('Enable system identity for Recovery Services vault')
param enableSystemIdentity bool = true

@description('Number of days Instant Recovery Point should be retained')
@allowed([
  1
  2
  3
  4
  5
])
param instantRpRetentionRangeInDays int = 2

@description('Times in day when backup should be triggered. e.g. 01:00 or 13:00. Must be an array, however for IaaS VMs only one value is valid. This will be used in LTR too for daily, weekly, monthly and yearly backup.')
param scheduleRunTimes array

@description('Prod or test environment')
@allowed([
  'prod'
  'test'
])
param environment string

@description('Azure Region')
param location string = deployment().location

@description('Suffix to make deployment names unique')
param deploymentNameSuffix string = utcNow()

@description('Network security group name.')
param networkSecurityGroupName string

@description('Automatic patching config')
param patchSettings object

@description('Name of the resource group')
param resourceGroup string

@description('Name of the Recovery Services Vault')
param rsvName string

@description('Sku of the vault')
param rsvSku string = 'RS0'

@description('Subnet range')
param subnetAddressRange string

@description('Name of the subnet')
param subnetName string

@description('All resources should be tagged')
param tags object

@description('Shutdown the VM daily to save cost in case we forget')
param vmAutoShutdownTime string

@description('The size of the VM')
param vmSize string

param vmSku string

@description('Virtual network IP address range.')
param vnetAddressRange string

@description('Vnet name')
param vnetName string

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

// a random name for the vm so we don't get DNS clashes
var vmName = toLower(uniqueString(subscription().id, rg.id, location))

// create the resource group
targetScope = 'subscription'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroup
  location: location
  tags: tags
}

module vnet './modules/network.bicep' = {
  name: 'networkDeployment.${deploymentNameSuffix}'
  params: {
    location: location
    networkSecurityGroupName: networkSecurityGroupName
    securityRules: securityRules
    subnetAddressRange: subnetAddressRange
    subnetName: subnetName
    tags: tags
    vnetAddressRange: vnetAddressRange
    vnetName: vnetName
  }
  scope: rg
}

// deploy vm
module vm './modules/vm.bicep' = {
  name: '${vmName}.${deploymentNameSuffix}'
  params: {
    adminPassword: adminPassword
    adminUserName: adminUserName
    autoShutdownEnabled: (environment =~ 'test')
    autoShutdownTime: vmAutoShutdownTime
    enablePublicIP: true
    fqdn: '${vmName}.${location}.cloudapp.azure.com'
    imageType: 'WindowsServer'
    location: location
    patchSettings: patchSettings
    protectWithLocks: (environment =~ 'prod')
    subnetName: subnetName
    tags: tags
    vmName: vmName
    vmSize: vmSize
    vmSku: vmSku
    vnetName: vnetName
    vnetResourceGroup: rg.name
  }
  scope: rg
  dependsOn: [
    vnet
  ]
}

// deploy recovery services vault
module rsv './modules/rsv.bicep' = {
  name: '${rsvName}.${deploymentNameSuffix}'
  params: {
    dailyRetentionDurationCount: dailyRetentionDurationCount
    daysOfTheWeek: daysOfTheWeek
    enablecrossRegionRestore: enablecrossRegionRestore
    enableSystemIdentity: enableSystemIdentity
    instantRpRetentionRangeInDays: instantRpRetentionRangeInDays
    location: location
    monthlyRetentionDurationCount: monthlyRetentionDurationCount
    scheduleRunTimes: scheduleRunTimes
    sku: rsvSku
    tags: tags
    vaultName: rsvName
    weeklyRetentionDurationCount: weeklyRetentionDurationCount
  }
  scope: rg
}

output vmName string = vmName
