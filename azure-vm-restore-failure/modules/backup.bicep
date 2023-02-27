param armProviderNamespace string = 'Microsoft.RecoveryServices'

@description ('Name of the Recovery Services Vault')
param vaultName string

@description('The recovery services vault backup policy to use')
param policyName string

param fabricName string = 'Azure'

@description('protection container in the vault')
param protectionContainer string

@description('item to protect')
param protectedItem string

@description('Azure resourceId of the VM to backup')
param sourceResourceId string

resource protectedvm 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2022-01-01' = {
  name: '${vaultName}/${fabricName}/${protectionContainer}/${protectedItem}'
  properties: {
    protectedItemType: 'Microsoft.Compute/virtualMachines'
    policyId: resourceId('${armProviderNamespace}/vaults/backupPolicies', vaultName, policyName)
    sourceResourceId: sourceResourceId
  }
}
