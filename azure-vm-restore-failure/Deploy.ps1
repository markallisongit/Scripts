<#
.SYNOPSIS
Deploy the Azure resources required for the demo

.DESCRIPTION
Deploys
* A recovery services vault
* A VM
* A job to backup the VM to the vault

.PARAMETER Location
The name of the Azure Region to deploy to e.g. uksouth

.PARAMETER Environment
The environment to deploy to. Multiple can be set up using parameter files.

.NOTES
Dependencies: Powershell 7

Article link: https://markallison.co.uk

Author: Mark Allison <home@markallison.co.uk>
#>
[cmdletbinding()]
param (
    [Parameter (Mandatory = $false)]  [string]      $Location = "uksouth",    
    [Parameter (Mandatory = $false)] [string]        $Environment = "test"
)
$ErrorActionPreference = 'Stop'

# Get my public IP
Write-Verbose "Getting my public IP"
$ip = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content

# obviously don't do this, this is just for convenience, use key vault fopr secrets
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
    -TemplateFile ./backup-item.bicep `
    -resourceGroup $output.Parameters.resourceGroup.Value `
    -rsvName $output.parameters.rsvName.Value `
    -vmName $output.Outputs.vmName.Value

