[cmdletbinding()]
param (
    [Parameter (Mandatory = $false)]  [string]    $Location = "uksouth"
)

$ErrorActionPreference = 'Stop'

# Get my public IP
Write-Verbose "Getting my public IP"
$ip = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content | ConvertTo-SecureString -AsPlainText -Force

# check deploying to correct subscription
$sub = Get-AzContext
if ($sub.Subscription.Name -ne "Marks HEE Private") {
    throw "$($sub.Subscription.Name) is the wrong subscription."
}

# load functions
# . .\functions.ps1

Write-Information "Deploying infra"
New-AzDeployment -Name core.deploy.$(Get-Date -Format "yyyyMMdd.HHmmss") `
    -Location $Location `
    -TemplateFile ./main.bicep `
    -TemplateParameterFile "./parameters/$Location.json" `
    -allowedIp $ip 