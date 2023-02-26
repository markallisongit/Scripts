[cmdletbinding()]
param (
    [Parameter (Mandatory = $false)]  [string]      $Location = "uksouth",    
    [Parameter (Mandatory = $false)] [string]        $Environment = "test"
)
$ErrorActionPreference = 'Stop'

# Get my public IP
Write-Verbose "Getting my public IP"
$ip = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content

# obviously don't do this, this is just for convenience, use key vault
$adminPassword = ConvertTo-SecureString 'MySec3rePa$$wordlol' -AsPlainText -Force

Write-Verbose "Deploying Vault and VM"
$output = New-AzDeployment -Name deploy.$(Get-Date -Format "yyyyMMdd.HHmmss") `
    -Location $Location `
    -TemplateFile ./main.bicep `
    -TemplateParameterFile "./parameters.$Environment.json" `
    -allowedIp $ip `
    -adminPassword $adminPassword `
    -environment $Environment

# we need to sleep to configure RSW with a new backup item
Write-Verbose "Sleeping before configuring Recovery Services Vault..."
Sleep -Seconds 120

Write-Verbose "Configuring Vault"
New-AzDeployment -Name deploy.$(Get-Date -Format "yyyyMMdd.HHmmss") `
    -Location $Location `
    -TemplateFile ./ConfigureVault.bicep `
    -resourceGroup $output.Parameters.resourceGroup.Value `
    -rsvName $output.parameters.rsvName.Value `
    -vmName $output.Outputs.vmName.Value

