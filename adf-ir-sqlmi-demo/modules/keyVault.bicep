@description('Name of the key vault')
param keyVaultName string

@description('The  location.')
param location string = resourceGroup().location

@description('Role assignments to apply to this key vault')
param roleAssignments array = []

@description('List of secrets to create in the vault')
param secrets array

@description('Number of days to keep deleted key vault')
param softDeleteRetentionInDays int = 7

@description('Tags for the resources.')
param tags object

@description('The Active Directory Tenant Id.')
param tenantId string

resource kv 'Microsoft.KeyVault/vaults@2022-11-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    enabledForDeployment: false
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: false
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    tenantId: tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for r in roleAssignments: {
  name: guid(r.PrincipalId, r.RoleDefinitionId, resourceGroup().id, keyVaultName)
  scope: kv
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', r.RoleDefinitionId)
    principalId: r.PrincipalId
  }
}]

resource sec 'Microsoft.KeyVault/vaults/secrets@2021-04-01-preview' = [for secret in secrets: {
  name: secret.name
  parent: kv
  properties: {
    value: secret.value
  }
}]
