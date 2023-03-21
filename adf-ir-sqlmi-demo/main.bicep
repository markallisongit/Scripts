@description('Azure Data Factory Name')
param adfName string

@description('A list of Object Ids in AAD to allow to ADF')
param adfRoleAssignments array

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

@description('A list of Object Ids in AAD to allow to Key Vault')
param keyVaultRoleAssignments array

@description('Azure Region')
param location string = deployment().location

@description('Name of the resource group')
param resourceGroup string

@description('Managed Instance Network security group name.')
param sqlmiNetworkSecurityGroupName string

@description('The SQLMI collation')
param sqlmiCollation string

@description('The license to use for SQLMI')
param sqlmiLicenseType string

@description('Name of the Managed Instance subnet route table')
param sqlmiRouteTableName string

@description('Managed Instance Compute type and capacity')
param sqlmiSkuName string

@description('Storage account type for PIT backups')
param sqlmiBackupStorageRedundancy string

@description('Initial Storage size for the SQLMI.')
param sqlmiStorageSizeInGB int

@description('MI subnet address IP range.')
param sqlmiSubnetAddressRange string

@description('Number of vCores')
param sqlmiVcores int

@description('vm Network security group name.')
param vmNetworkSecurityGroupName string

@description('The size of the VM')
param vmSize string

@description('MI subnet address IP range.')
param vmSubnetAddressRange string

@description('Virtual network IP address range.')
param vnetAddressRange string

@description('Name of the subnet for the VM.')
param vmSubnetName string = 'vm-subnet'

@description('All resources should be tagged :)')
param tags object

param tenantId string = subscription().tenantId

@description('Vnet name')
param vnetName string

// create a unique suffix to prevent global name clashes
var suffix = toLower(uniqueString(subscription().id, rg.id))

// key vault name
var kvName = 'kv${suffix}'
// vm name
var vmName = 'vm${suffix}'

// allow my public IP
var vmSecurityRules = [
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

var sqlmiSecurityRules = []
/*
[
  {
    name: 'let-me-in'
    properties: {
      priority: 1000
      sourceAddressPrefix: allowedIp
      protocol: 'Tcp'
      destinationPortRanges: [
        3342
      ]
      access: 'Allow'
      direction: 'Inbound'
      sourcePortRange: '*'
      destinationAddressPrefix: '*'
    }
  }
]
*/

// Storage Account Name for ADLS
var storageAccountName = 'sa${suffix}'

// sqlmi name
var sqlmiName = 'sqlmi${suffix}'
var secrets = [
  {
    name: adminUserName
    value: adminPassword
  }
]

// create the resource group
targetScope = 'subscription'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroup
  location: location
  tags: tags
}

// create a keyvault to re-use secrets
module kv './modules/keyVault.bicep' =  {
  name: '${kvName}.${deploymentNameSuffix}'
  params: {
    keyVaultName: kvName
    location: location
    roleAssignments: keyVaultRoleAssignments
    secrets: secrets
    tags: tags
    tenantId: tenantId
  }
  scope: rg
}

//  create vnet
module vnet './modules/vnet.bicep' = {
  name: '${vnetName}.${deploymentNameSuffix}'
  params: {
    allowedIp: allowedIp
    location: rg.location
    sqlmiNetworkSecurityGroupName: sqlmiNetworkSecurityGroupName
    sqlmiRouteTableName: sqlmiRouteTableName
    sqlmiSecurityRules: sqlmiSecurityRules
    sqlmiSubnetAddressRange: sqlmiSubnetAddressRange
    tags: tags
    vmNetworkSecurityGroupName: vmNetworkSecurityGroupName
    vmSecurityRules: vmSecurityRules
    vmSubnetName: vmSubnetName
    vmSubnetAddressRange: vmSubnetAddressRange
    vnetAddressRange: vnetAddressRange
    vnetName: vnetName
  }
  scope: rg
}

// create the vm for hosting IR
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
    vnetName: vnetName
    vnetResourceGroup: resourceGroup
    pipSku: 'Basic'
  }
  scope: rg
  dependsOn: [
    vnet
  ]
}

// create a SQLMI
module sqlmi './modules/mi.bicep' = {
  name: '${sqlmiName}.${deploymentNameSuffix}'
  params: {
    adminLogin: adminUserName
    adminPassword: adminPassword
    backupStorageRedundancy: sqlmiBackupStorageRedundancy
    collation: sqlmiCollation
    licenseType: sqlmiLicenseType
    location: rg.location    
    sqlmiName: sqlmiName
    sqlmiSkuName: sqlmiSkuName
    sqlmiStorageSizeInGB: sqlmiStorageSizeInGB
    sqlmiVcores: sqlmiVcores
    tags: tags
    vnetName: vnetName
    vnetResourceGroupName: resourceGroup
  }
  scope: rg
}

module adf './modules/adf.bicep' = {
  name: '${adfName}.${deploymentNameSuffix}'
  params: {
    location: location
    name: adfName
    roleAssignments: adfRoleAssignments
    tags: tags
  }
  scope: rg
}

// ADLS
module storageAcct './modules/storage.bicep' =  {
  name: '${storageAccountName}.${deploymentNameSuffix}'
  params: {
    location: rg.location
    name: storageAccountName
    storageProperties: {
      accessTier: 'Hot'
      isHnsEnabled: true
    }
    tags: tags    
  }
  scope: rg
}

output vmName string = vmName
output keyVaultName string = kvName
output sqlmiName string = sqlmiName
output storageAccountName string = storageAccountName
