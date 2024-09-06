<#
.SYNOPSIS
Generates scripts to remove NOLOCK hints
Also included is a script to revert if it goes wrong for some reason

.DESCRIPTION
Generates two scripts:
* One to remove the NOLOCK hints (deploy)
* One to add them back again (revert)

.PARAMETER InstanceName
The SQL Server instance where the database resides

.PARAMETER DatabaseName
The database to scan for objects with NOLOCK hints

.PARAMETER ScriptPath
Optional. Where to put the output scripts. Defaults to the same location as this script

.PARAMETER SqlCredential
Optional. Use Get-Credential to use SQL Auth, if omitted will use Windows Auth.
I didn't get time to create an AAD version sorry.

.NOTES
Dependencies: Powershell 7, dbatools module (gets installed)

Article link: https://markallison.co.uk

Author: Mark Allison <home@markallison.co.uk>

* There's no feedback because it runs quite quickly.
* I didn't add functions.

Feel free to submit a PR :)
#>
[cmdletbinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$InstanceName,

    [Parameter(Mandatory=$true)]
    [string]$DatabaseName,

    [string]$ScriptPath = $PSScriptRoot,

    [PSCredential]$SqlCredential
)

$ErrorActionPreference = 'Stop'

# Check for PowerShell 7 or later
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Throw "This script requires PowerShell 7 or later. Current version: $($PSVersionTable.PSVersion)"
}

# Check if dbatools module is installed
$module = Get-Module -ListAvailable -Name "dbatools"

if (-not $module) {
    $installResponse = Read-Host "The REQUIRED dbatools module is not installed. Would you like to install it? (Y/N)"
    
    if ($installResponse -eq "Y" -or $installResponse -eq "y") {
        # Attempt to install the dbatools module
        try {
            Install-Module -Name dbatools -Force -AllowClobber
            Write-Host "dbatools module successfully installed."
        } catch {
            Throw "Failed to install the dbatools module. Please try installing it manually."
        }
    } else {
        # User chose not to install the module, throw an error
        Throw "dbatools module is required for this script. Please install it and try again."
    }
}

$query = @"
SELECT 
	s.name AS SchemaName,
    o.name AS ObjectName,
    m.definition AS ObjectDefinition
FROM
    sys.sql_modules m
INNER JOIN
    sys.objects o ON m.object_id = o.object_id
INNER JOIN
	sys.schemas s ON s.schema_id = o.schema_id
WHERE
    m.definition LIKE '%NOLOCK%'
and o.name NOT IN (
    'sp_Blitz',
    'sp_BlitzIndex'
)
ORDER BY o.type 
"@

# Check if SQL Authentication credentials are provided
if ($SqlCredential) {
    # Use SQL Authentication
    $conn = Connect-DbaInstance -SqlInstance $InstanceName -Database $DatabaseName -SqlCredential $SqlCredential -TrustServerCertificate
} else {
    # Use Windows Authentication
    $conn = Connect-DbaInstance -SqlInstance $InstanceName -Database $DatabaseName -TrustServerCertificate
}

# Get the object definitions we want to change
$objectsToScan = Invoke-DbaQuery -SqlInstance $conn -Query $query

# Initialize arrays to store the SQL statements
$revertSql = @()
$deploySql = @()

foreach ($object in $objectsToScan) {
    $revert = $object.ObjectDefinition `
        -replace 'CREATE\s+PROCEDURE', 'CREATE OR ALTER PROCEDURE' `
        -replace 'CREATE\s+VIEW', 'CREATE OR ALTER VIEW'
    
    $deploy = $object.ObjectDefinition `
        -replace 'CREATE\s+PROCEDURE', 'CREATE OR ALTER PROCEDURE' `
        -replace 'CREATE\s+VIEW', 'CREATE OR ALTER VIEW' `
        -replace 'WITH\s*\(\s*NOLOCK\s*\)', '' `
        -replace 'WITH\s*\(\s*NOLOCK\s*\)', '' `
        -replace 'WITH\s*\(\s*NOLOCK\s*\)', '' `
        -replace '\(\s*NOLOCK\s*\)', '' `
        -replace ',\s*NOLOCK', '' `
        -replace 'NOLOCK\s*,', '' `
        -replace '\bNOLOCK\b', '' `
        -replace 'WITH\s*\(\s*\)', '' `
        -replace '\(\s*,', '(' `
        -replace ',\s*\)', ')' `
        -replace '\(\s*\)', '()'
        
    # Append the procedure definition and GO statement to the arrays
    $revertSql += "$revert`r`nGO`r`n"
    $deploySql += "$deploy`r`nGO`r`n"
}

# Convert arrays to strings
$revertSqlString = [string]::Join("`r`n", $revertSql)
$deploySqlString = [string]::Join("`r`n", $deploySql)

# Save to files
$datetime = Get-Date -Format "yyyyMMdd-HHmmss"
$revertFile = "$($ScriptPath)\$($InstanceName)-$($DatabaseName)-Revert-$($datetime).sql"
$deployFile = "$($ScriptPath)\$($InstanceName)-$($DatabaseName)-Deploy-$($datetime).sql"

$revertSqlString | Out-File -FilePath $revertFile -Encoding UTF8
$deploySqlString | Out-File -FilePath $deployFile -Encoding UTF8