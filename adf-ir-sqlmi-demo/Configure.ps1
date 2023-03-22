[cmdletbinding()]
param (
    [Parameter (Mandatory = $false)]  [string]    $Location = "uksouth"
)

# read the parameters file
$params = (Get-Content -Path "./parameters/$($location).json" | ConvertFrom-Json).parameters

# Get Key Vault details
$kv = Get-AzKeyVault -ResourceGroupName $params.resourceGroup.value

# Grant ADF ManagedIdentity access to Key vault
$adfPrincipal = Get-AzADServicePrincipal -DisplayName $params.adfName.value
New-AzRoleAssignment `
    -ObjectId $adfPrincipal.Id `
    -RoleDefinitionName "Key Vault Secrets User" `
    -Scope $kv.ResourceId

# Grant ADF ManagedIdentity Access to Azure Data Lake
$adls = Get-AzStorageAccount -ResourceGroupName $params.resourceGroup.value
New-AzRoleAssignment `
    -ObjectId $adfPrincipal.Id `
    -RoleDefinitionName "Storage Blob Data Contributor" `
    -Scope $adls.Id

Get-AzRoleAssignment `
-ObjectId $adfPrincipal.Id `
-RoleDefinitionName "Storage Blob Data Contributor" `
-Scope $adls.Id