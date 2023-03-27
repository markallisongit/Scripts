@description('Location.')
param location string = resourceGroup().location

@description('Name of the data factory')
param name string

@description('An array of roleAssignments to grant to the factory')
param roleAssignments array = []

@description('Azure DevOps repo details. i.e. where the source code resides')
param repoConfiguration object = {}

@description('Tags for the resources.')
param tags object

resource adf 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    repoConfiguration: repoConfiguration
  }
}

// roleAssignments for Data Factories
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for r in roleAssignments: {
  scope: adf
  name: guid(r.PrincipalId, r.RoleDefinitionId, resourceGroup().id,name)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', r.RoleDefinitionId)
    principalId: r.PrincipalId
  }
}]

output permissionsGranted array = roleAssignments
