$Environment = 'test'

# read the parameters file to make things easier
$params = (Get-Content .\parameters.$Environment.json | ConvertFrom-Json).parameters
$rg = Get-AzResourceGroup -Name $params.resourceGroup.value
$vm = Get-AzVM -ResourceGroupName $rg.ResourceGroupName 

$snapShotName = "$($vm.Name)-$(Get-Date -Format 'yyyyMMdd-HHmmss')-snapshot"

# Take a snapshot of the VM OS Disk
$snapshotConfig = New-AzSnapshotConfig -SourceUri $vm.StorageProfile.OsDisk.ManagedDisk.Id -Location $rg.Location -CreateOption copy
$snapshot = New-AzSnapshot -Snapshot $snapshotConfig -SnapshotName $snapShotName -ResourceGroupName $rg.ResourceGroupName

# create a new Managed Disk from the snapshot
$snapshot = Get-AzSnapshot -ResourceGroupName $rg.ResourceGroupName -SnapshotName $snapShotName
$storageType = 'Premium_LRS'
$diskConfig = New-AzDiskConfig -SkuName $storageType -Location $rg.Location -CreateOption Copy -SourceResourceId $snapshot.Id 
$disk = New-AzDisk -Disk $diskConfig -ResourceGroupName $rg.ResourceGroupName -DiskName 'ReplacedOSDisk'

# imagine we've restored an old working version of the VM

# Swap the OS disk in the restored VM that is blue screening for the Newly created OS Disk
$vm | Stop-AzVM -Force
Set-AzVMOSDisk -VM $vm -ManagedDiskId $disk.Id -Name $disk.Name
Update-AzVM -ResourceGroupName $rg.ResourceGroupName -VM $vm
$vm | Start-AzVM

# VM should now be recovered