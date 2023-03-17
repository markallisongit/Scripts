@description('local administrator user name for the Azure SQL Virtual Machines')
param adminUserName string

@description('Time to auto shutdown the VM')
param autoShutdownTime string = '20:00'

@description('Enable auto shutdown the VM')
param autoShutdownEnabled bool = true

@description('local administrator password for the Azure SQL Virtual Machines')
@secure()
param adminPassword string

@description('Name of the subnet that the Azure SQL Virtual Machines are connected to')
param subnetName string

param location string = resourceGroup().location

@description('Virtual Machines OS Disk type')
param osDiskType string = 'Premium_LRS'

@description('Public Ip address Sku')
param pipSku string = 'Standard'

param tags object

@description('VM Name')
param vmName string

@description('Size for the Azure Virtual Machines')
param vmSize string

@description('Name of the VNet that the Azure SQL Virtual Machines are connected to')
param vnetName string

param vnetResourceGroup string

var nicName = '${vmName}-nic1'
var pipName = '${vmName}-pip'
// var vmFqdn = '${vmName}.${location}.cloudapp.azure.com'
var vmDnsName = vmName

// this is the existing VNet
resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetResourceGroup)
}

// This is the existing subnet in the existing vnet
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: subnetName
  parent: vnet
}

// the public ipv4 address of the VM
resource pip 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: pipName
  location: location
  tags: tags
  sku: {
    name: pipSku
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
    dnsSettings: {
      domainNameLabel: vmDnsName
    }
  }
}

// a network interface must be created first and assigned the IP address
resource nic 'Microsoft.Network/networkInterfaces@2022-01-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfigv4'
        properties: {
          primary: true
          privateIPAddressVersion: 'IPv4'
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pip.id
          }
          subnet: {
            id: subnet.id
          }
        }
      }
    ]
    enableAcceleratedNetworking: false
  }
}

// this section defines the VM configuration
resource vm 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
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
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUserName
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          enableHotpatching: false
        }
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    licenseType: 'Windows_Client'
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
    targetResourceId: vm.id
  }
}
