@description('The Run Command resource name.')
param name string

@description('The Virtual Machine location.')
param location string = resourceGroup().location

@description('The script content to be executed on the VM.')
param script string

@description('The timeout in seconds to execute the run command. Minimum value is 120 seconds (2 minutes) and default value is 300 seconds (5 minutes). Maximum value is 5400 seconds (90 minutes).')
@minValue(120)
@maxValue(5400)
param timeoutInSeconds int = 120

resource vm_run_cmd 'Microsoft.Compute/virtualMachines/runCommands@2021-07-01' = {
  name: name
  location: location
  properties: {
    source: {
      script: script
    }
    timeoutInSeconds: timeoutInSeconds
  }
}

output result object = vm_run_cmd
