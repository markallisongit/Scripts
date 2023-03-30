[cmdletbinding()]
param (
    [Parameter (Mandatory = $false)]  [string]    $Location = "uksouth",
    [Parameter (Mandatory = $false)]  [string]    $Subscription = "HEE DATA WAREHOUSE"
)
function ConvertToHashTable {
    param (
        $rules
    )

    $inboundPosition = 100
    $outboundPosition = 100
    $index = 0

    $result = [Object[]]::new($rules.Length)
 

    foreach ($rule in $rules) {
        
        $ruleHash = @{}

        $ruleHash["name"] = "Microsoft.Sql-managedInstances_UseOnly_" + $rule.name

        $propertiesHash = @{};

        foreach ($property in $rule.properties.PSObject.Properties) {
            $name = $property.Name
            $value = $property.Value
            if ($name -eq "sourceAddressPrefixes" -and $value.Length -eq 1) {
                $name = "sourceAddressPrefix"
                $value = $value[0]
            }
            if ($name -eq "destinationAddressPrefixes" -and $value.Length -eq 1) {
                $name = "destinationAddressPrefix"
                $value = $value[0]
            }
            if ($name -eq "sourcePortRanges" -and $value -eq '*') {
                $name = "sourcePortRange"
                $value = "*"
            }
            if ($name -eq "destinationPortRanges" -and $value -eq '*') {
                $name = "destinationPortRange"
                $value = "*"
            }
            if ($name -eq "direction" -and $value -eq 'Inbound') {
                $propertiesHash['priority'] = $inboundPosition++
    
            }
            if ($name -eq "direction" -and $value -eq 'Outbound') {
                $propertiesHash['priority'] = $outboundPosition++
            }
            if (
                $name -ne 'addedBySystem' -and
                $name -ne 'provisioningState'
            ) {
                $propertiesHash[$name] = $value
            }
        }

        $ruleHash["properties"] = $propertiesHash

        $result[$index++] = $ruleHash
    }

    return $result
}
$ErrorActionPreference = 'Stop'

Write-Information "Exporting network policies for SQLMI"

# for new deployments we don't have any network intent policy, so create empty arrays
"[]" > "$PSScriptRoot\network-intent-policy-rules.json"
"[]" > "$PSScriptRoot\network-intent-policy-routes.json"        

# Get my public IP
Write-Verbose "Getting my public IP"
$ip = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content | ConvertTo-SecureString -AsPlainText -Force

# read the parameters file
$params = (Get-Content -Path "./parameters/$($location).json" | ConvertFrom-Json).parameters

# check deplying to correct subscription
$sub = Get-AzContext
if ($sub.Subscription.Name -ne $Subscription) {
    throw "$($sub.Subscription.Name) is the wrong subscription."
}

$ResourceGroup = $params.resourceGroup.value

$securityRules = @()
$routes = @()
$apiVersion = "2020-07-01"

if (Get-AzResourceGroup | where { $_.ResourceGroupName -eq $ResourceGroup }) {
    Write-Information "Getting VNet info for existing resource group: $ResourceGroup"
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroup
    # $vnet.SubnetsText

    if ($null -ne $vnet) {
        $miSubnetResourceId = ($vnet.Subnets | where { $_.Name -eq 'ManagedInstance' }).Id

        if ($null -ne $miSubnetResourceId) { 
            Write-Information "Getting subnet"
            # get the MI subnet
            $subnet = Get-AzResource -ResourceId $miSubnetResourceId -ApiVersion $apiVersion
		
            if ($subnet.Properties.networkIntentPolicies.Length -gt 0) {
                Write-Information "Getting rules from the network policy"
                $nipId = $subnet.Properties.networkIntentPolicies[0].id
                $nip = Get-AzResource -ResourceId $nipId -ApiVersion $apiVersion 
                $securityRules = $nip.Properties.securityRules
                $routes = $nip.Properties.routes
                $securityRules = ConvertToHashTable $securityRules   
                $securityRules | ConvertTo-Json -Depth 3 > "$PSScriptRoot\network-intent-policy-rules.json"

                $routes = ConvertToHashTable $routes    
                $routes | ConvertTo-Json -Depth 3 > "$PSScriptRoot\network-intent-policy-routes.json"
            }
            else {
                Write-Information "Network policy not found"
            }
        }
        else {
            Write-Information "Subnet not found"
        }
    }
    else {
        Write-Information "VNet not found"
    }

    Write-Information "Get secret from key vault if exists"
    $kv = Get-AzKeyVault -ResourceGroupName $ResourceGroup
}
else {
    Write-Information "Resource Group $ResourceGroup not found"
}

$myAccount = Get-AzADUser -UserPrincipalName $sub.Account

$keyVaultRoleAssignments = @(
    @{
        RoleDefinitionId = (Get-AzRoleDefinition -Name "Key Vault Secrets User").Id
        PrincipalId      = $myAccount.Id
    },
    @{
        RoleDefinitionId = (Get-AzRoleDefinition -Name "Key Vault Secrets Officer").Id
        PrincipalId      = $myAccount.Id
    }
)

$adfRoleAssignments = @(
    @{
        RoleDefinitionId = (Get-AzRoleDefinition -Name "Data Factory Contributor").Id
        PrincipalId      = $myAccount.Id
    }
)


# Define the deployment parameters
$deployParams = @{
    Name                    = "vm.deploy.$(Get-Date -Format 'yyyyMMdd.HHmmss')"
    Location                = $Location
    TemplateFile            = "./main.bicep"
    TemplateParameterFile   = "./parameters/$Location.json" 
    allowedIp               = $ip 
    keyVaultRoleAssignments = $keyVaultRoleAssignments
    adfRoleAssignments      = $adfRoleAssignments
}

if ($kv) {
    Write-Information "Found key vault $($kv.VaultName). Using existing secret."
    $secret = Get-AzKeyVaultSecret -VaultName $kv.VaultName -Name $params.adminUserName.value
    if ($secret) {
        $deployParams.Add("adminPassword", $secret.SecretValue)
    }
    else {
        Write-Information "Could not find secret $($params.adminUserName.value) in $($kv.VaultName)"
    }
    
}

Write-Information "Deploying infra"
New-AzDeployment @deployParams