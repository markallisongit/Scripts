@description('Default admin user name.')
param adminLogin string

@description('Default admin password.')
@secure()
param adminPassword string

@description('Storage account type for PIT backups')
param backupStorageRedundancy string

@description('The instance collation')
param collation string

@description('The license to use for SQLMI')
param licenseType string

@description('The location.')
param location string

@description('Minimum TLS version to enforce for inbound connections')
param minimalTlsVersion string = '1.2'

@description('The managed instance name.')
param sqlmiName string

@description('Managed Instance Compute type and capacity')
param sqlmiSkuName string

@description('Storage size for each instance.')
param sqlmiStorageSizeInGB int

@description('Number of vCores')
param sqlmiVcores int

@description('Tags for the resources.')
param tags object

@description('The vNet to install to')
param vnetName string

@description('Resource group where the vnet resides.')
param vnetResourceGroupName string

// The existing vnet
resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetResourceGroupName)
}

resource managedInstance 'Microsoft.Sql/managedInstances@2022-08-01-preview' = {
  name: sqlmiName
  location: location
  tags: tags
  sku: {
    name: sqlmiSkuName
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
    collation: collation
    licenseType: licenseType
    minimalTlsVersion: minimalTlsVersion    
    requestedBackupStorageRedundancy: backupStorageRedundancy
    storageSizeInGB: sqlmiStorageSizeInGB
    vCores: sqlmiVcores
    subnetId: resourceId(vnetResourceGroupName,'Microsoft.Network/virtualNetworks/subnets', vnetName, 'ManagedInstance')
    timezoneId: 'UTC'
  }
  dependsOn: [
    vnet
  ]  
}
