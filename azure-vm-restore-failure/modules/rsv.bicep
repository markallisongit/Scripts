@description('Location of Recovery Services vault')
param location string

@description('Number of days you want to retain the backup')
param dailyRetentionDurationCount int

@description('Backup will run on array of Days like, Monday, Tuesday etc. Applies in Weekly retention only.')
param daysOfTheWeek array

@description('Number of weeks you want to retain the backup')
param weeklyRetentionDurationCount int

@description('Number of months you want to retain the backup')
param monthlyRetentionDurationCount int

@description('Enable cross region restore')
param enablecrossRegionRestore bool = true

@description('Enable system identity for Recovery Services vault')
param enableSystemIdentity bool = true

@description('Number of days Instant Recovery Point should be retained')
@allowed([
  1
  2
  3
  4
  5
])
param instantRpRetentionRangeInDays int = 2

@description('Times in day when backup should be triggered. e.g. 01:00 or 13:00. Must be an array, however for IaaS VMs only one value is valid. This will be used in LTR too for daily, weekly, monthly and yearly backup.')
param scheduleRunTimes array

@description('The Sku name')
@allowed([
  'Standard'
  'RS0'
])
param sku string

@description('Storage replication type for Recovery Services vault')
@allowed([
  'LocallyRedundant'
  'GeoRedundant'
  'ReadAccessGeoZoneRedundant'
  'ZoneRedundant'
])
param storageType string = 'GeoRedundant'

@description('All resources should be tagged')
param tags object

@description('Recovery Services vault name')
param vaultName string

resource vault 'Microsoft.RecoveryServices/vaults@2022-01-01' = {
  name: vaultName
  location: location
  identity: {
    type: enableSystemIdentity ? 'SystemAssigned' : 'None'
  }
  properties: {}
  sku: {
    name: sku
    tier: 'Standard'
  }
  tags: tags
}

resource backupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2021-06-01' = {
  parent: vault
  name: 'DailyPolicy'
  location: location
  properties: {
    backupManagementType: 'AzureIaasVM'
    timeZone: 'GMT Standard Time'
    instantRpRetentionRangeInDays: instantRpRetentionRangeInDays
    schedulePolicy: {
      scheduleRunFrequency: 'Daily'
      scheduleRunTimes: scheduleRunTimes
      schedulePolicyType: 'SimpleSchedulePolicy'
    }
    retentionPolicy: {
      dailySchedule: {
        retentionTimes: scheduleRunTimes
        retentionDuration: {
          count: dailyRetentionDurationCount
          durationType: 'Days'
        }
      }
      weeklySchedule: {
        daysOfTheWeek: daysOfTheWeek
        retentionTimes: scheduleRunTimes
        retentionDuration: {
          count: weeklyRetentionDurationCount
          durationType: 'Weeks'
        }
      }
      monthlySchedule: {
        retentionScheduleFormatType: 'Daily'
        retentionScheduleDaily: {
          daysOfTheMonth: [
            {
              date: 1
              isLast: false
            }
          ]
        }
        retentionTimes: scheduleRunTimes
        retentionDuration: {
          count: monthlyRetentionDurationCount
          durationType: 'Months'
        }
      }
      retentionPolicyType: 'LongTermRetentionPolicy'
    }
  }
}

resource vaultConfig 'Microsoft.RecoveryServices/vaults/backupstorageconfig@2021-04-01' = {
  name: '${vault.name}/VaultStorageConfig'  
  properties: {
    crossRegionRestoreFlag: enablecrossRegionRestore
    storageType: storageType
  }
}
