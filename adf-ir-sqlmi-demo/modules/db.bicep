param dbName string
param sqlmi string
param tags object
param location string

// reference to the SQLMI 
resource mi 'Microsoft.Sql/managedInstances@2022-08-01-preview' existing = {
  name: sqlmi
}

// create a test db
resource db 'Microsoft.Sql/managedInstances/databases@2022-08-01-preview' = {
  location: location
  name: dbName
  tags: tags
  parent: mi

}
