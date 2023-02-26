# read the parameters file to get the values
$params = (Get-Content parameters.test.json | ConvertFrom-Json).parameters

if ((Read-Host "Confirm DELETE Resource Group $($params.resourceGroup.value) (y/n)") -ne 'y') {
    return
}

# switch off RSV soft delete
Write-Verbose "Removing soft delete"
$rsv = Get-AzRecoveryServicesVault -ResourceGroupName $params.resourceGroup.value
Set-AzRecoveryServicesVaultProperty -VaultId $rsv.ID -SoftDeleteFeatureState Disable

# remove the backup items and data
if ($rsv) {
    $Container = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -VaultId $rsv.ID
}
if ($Container) {
    $BackupItem = Get-AzRecoveryServicesBackupItem -Container $Container -WorkloadType AzureVM -VaultId $rsv.ID
}

if ($BackupItem) {
    Write-Verbose "Disabling backup protection and deleting data"
    Disable-AzRecoveryServicesBackupProtection -Item $BackupItem -VaultId $rsv.ID -RemoveRecoveryPoints -Force
}

# delete the resource group
Write-Verbose "Deleting resource group"
Remove-AzResourceGroup -Name $params.resourceGroup.value -Force -Confirm:$false