@description('The recovery services vault backup policy to use')
param backupPolicyName string = 'DailyPolicy'

@description('Suffix to make deployment names unique')
param deploymentNameSuffix string = utcNow()

@description('Name of the Recovery Services Vault')
param rsvName string

param vmName string

@description('Name of the resource group')
param resourceGroup string

var protectedItem = 'vm;iaasvmcontainerv2;${resourceGroup};${vmName}'
var protectionContainer = 'iaasvmcontainer;iaasvmcontainerv2;${resourceGroup};${vmName}'

targetScope = 'subscription'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: resourceGroup
}

resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: vmName
  scope: rg
}

// set up the backup for the vm in recovery services vault
module backupvm './modules/backup.bicep' = {
  name: 'backupVm.${deploymentNameSuffix}'
  params: {
    policyName: backupPolicyName
    protectionContainer: protectionContainer
    protectedItem: protectedItem
    sourceResourceId: vm.id
    vaultName: rsvName
  }
  scope: rg
}
