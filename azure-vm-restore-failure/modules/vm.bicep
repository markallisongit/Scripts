@description('Default local Administrator password')
@secure()
param adminPassword string

@description('Default local Administrator account name')
param adminUserName string

@description('Time to auto shutdown the VM')
param autoShutdownTime string = ''

@description('Enable auto shutdown the VM')
param autoShutdownEnabled bool

@description('The internal hostname')
param computerName string = ''

@description('data disk configurations for the Azure Virtual Machines')
param dataDisks array = []

@description('Create a public IP Address for the VM')
param enablePublicIP bool = false

@description('The fully qualified domain name of the VM')
param fqdn string

@description('The Base OS image for the VM')
@allowed([
  'MicrosoftSQLServer'
  'MicrosoftWindowsServer'
])
param imagePublisher string = 'MicrosoftWindowsServer'

@description('The Base OS image for the VM')
param imageType string

@description('Location for all resources.')
param location string

@description('The network interface card name')
param nicName string = '${vmName}-nic1'

@description('OS Managed Disk')
param osDiskType string = 'Premium_LRS'

@description('Automatic patching settings')
param patchSettings object

@description('Public Ip name')
param pipName string = '${vmName}-pip1'

@description('Public Ip address Sku')
param pipSku string  = 'Basic'

@description('Prod resources should be locked to prevent accidental deletion')
param protectWithLocks bool

@description('Name of the subnet in the virtual network to use')
param subnetName string = 'etl-subnet'

@description('Tags for the VM resources.')
param tags object

@description('The VM name')
param vmName string

@description('Size of the VM')
param vmSize string

@description('The VM image sku')
param vmSku string

@description('Name of the existing VNET')
param vnetName string

@description('Name of the existing VNET resource group')
param vnetResourceGroup string

var subnetRef = resourceId(vnetResourceGroup, 'Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)

// if test, we don't want to create a public IP
var ipSettings = {
  disablePublicIp: {
    privateIPAllocationMethod: 'Dynamic'
    subnet: {
      id: subnetRef
    }
  }
  enablePublicIp: {
    privateIPAllocationMethod: 'Dynamic'
    publicIPAddress: {
      id: pip.id
    }
    subnet: {
      id: subnetRef
    }
  }
}

// this is the existing VNet
resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetResourceGroup)
}

// This is the existing ETL subnet in the existing vnet
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  name: subnetName
  parent: vnet
}

// only create public IP if prod
resource pip 'Microsoft.Network/publicIPAddresses@2022-01-01' = if(enablePublicIP) {
  name: pipName
  location: location
  tags: tags
  sku: {
    name: pipSku
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: vmName
      //fqdn: '${vmName}.${location}.cloudapp.azure.com'
      fqdn: fqdn
    }
  }
}

resource piplock 'Microsoft.Authorization/locks@2016-09-01' = if(protectWithLocks && enablePublicIP) {
  name: '${pipName}-lock'
  scope: pip
  properties: {
    level: 'CanNotDelete'
    notes: 'Public IP should not be deleted.'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: enablePublicIP ? ipSettings.enablePublicIp : ipSettings.disablePublicIp
      }
    ]
  }
}

resource niclock 'Microsoft.Authorization/locks@2016-09-01' = if(protectWithLocks) {
  name: '${nicName}-lock'
  scope: nic
  properties: {
    level: 'CanNotDelete'
    notes: 'NIC should not be deleted.'
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: {
        publisher: imagePublisher
        offer: imageType
        sku: vmSku
        version: 'latest'
      }
      dataDisks: [for (disk, i) in dataDisks: {
        lun: i
        // hack because the westeurope prod data disks were created with wrong createOption
        createOption: (location == 'westeurope' && protectWithLocks == true) ? 'attach': disk.createOption
        caching: disk.caching
        writeAcceleratorEnabled: disk.writeAcceleratorEnabled
        diskSizeGB: disk.diskSizeGB
        managedDisk: {
          storageAccountType: disk.storageAccountType
        }
      }]      
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    osProfile: {
      computerName: empty(computerName) ? vmName : computerName
      adminUsername: adminUserName
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: patchSettings
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
  dependsOn: [
    vnet
    subnet
  ]
}

resource vmlock 'Microsoft.Authorization/locks@2016-09-01' = if(protectWithLocks) {
  name: '${vmName}-lock'
  scope: vm
  properties: {
    level: 'CanNotDelete'
    notes: 'VM should not be deleted.'
  }
}

// this shuts down the VM at the end of the day, if enabled
resource vmschedule 'Microsoft.DevTestLab/schedules@2018-09-15' = if (autoShutdownEnabled) {
  name: 'shutdown-computevm-${vmName}'
  location: location
  tags: tags
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: autoShutdownTime      
    }
    timeZoneId: 'UTC'
    targetResourceId: resourceId('Microsoft.Compute/virtualMachines', vmName)
  }
  dependsOn: [
    vm
  ]
}
