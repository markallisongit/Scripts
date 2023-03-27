@description('Name of the storage account')
param name string

@description('Location for the account')
param location string

@description('The account kind, dont change')
param kind string = 'StorageV2'

@description('The redundancy required for the account')
param skuName string = 'Standard_LRS'

@description('The storage account properties')
param storageProperties object

@description('Tags for the storage resources.')
param tags object

resource storageAcct 'Microsoft.Storage/storageAccounts@2021-02-01' =  {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  kind: kind
  properties: storageProperties
}
