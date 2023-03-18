[cmdletbinding()]
param (
    [Parameter (Mandatory = $false)]  [string]    $Location = "uksouth"
)
$ErrorActionPreference = 'Stop'

# read the parameters file
$params = (Get-Content -Path "./parameters/$($location).json" | ConvertFrom-Json).parameters

# check deploying to correct subscription
$sub = Get-AzContext
if ($sub.Subscription.Name -ne "Marks Private") {
    throw "$($sub.Subscription.Name) is the wrong subscription."
}

# Get the existing VM
$vm = Get-AzVM -ResourceGroupName $params.resourceGroup.value




# Nics can be created separate from a VM but not recommended
# because they cannot be attached to a VM that has a NIC attached to a different Vnet
# a nic can be created separately to attach to a VM but it must be in the same vnet or it won't attach

# get the osdisk
$osdisk = Get-AzDisk -ResourceGroupName $params.resourceGroup.value | ? {$_.Name -eq $vm.StorageProfile.OsDisk.Name }

if (-not $osdisk) {
    throw "Could not find OS Disk for $($vm.Name). Aborting move."
}

# delete the vm and nic
$vmName = $vm.Name
$vm | Remove-AzVM -Force

# get the public IP
$pip = Get-AzPublicIpAddress -ResourceGroupName $params.resourceGroup.value

# get vnet2 that we want to attach the VM to
$vnet = Get-AzVirtualNetwork -ResourceGroupName $params.resourceGroup.value -Name $params.vnet2Name.value

# get the vm-subent
$subnet = $vnet.Subnets | ? {$_.Name -eq $params.vnet2SubnetName.value}

# create an ip configuration for the NIC
$ipconfig = New-AzNetworkInterfaceIpConfig `
    -Name "IpConfiguration" `
    -Subnet $subnet `
    -PublicIpAddress $pip `
    -Primary

# create a new NIC attached to vnet2
$nic = New-AzNetworkInterface `
    -Name "$($vmName)-nic2" `
    -ResourceGroupName $params.resourceGroup.value `
    -IpConfiguration $ipconfig `
    -Location $Location


# create a new VM configuration
$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $params.vmSize.value

# add the new nic to the config
$vm = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

# add the OS disk to the config
$vm = Set-AzVMOSDisk -VM $vm `
    -ManagedDiskId $osDisk.Id `
    -CreateOption Attach `
    -Windows

# Use managed storage for the boot diagnostics
$vm = Set-AzVMBootDiagnostic `
    -VM $vm `
    -Enable `
    -ResourceGroupName $params.resourceGroup.value 

# Create the VM
New-AzVM -ResourceGroupName $params.resourceGroup.value `
    -Location $location `
    -VM $vm