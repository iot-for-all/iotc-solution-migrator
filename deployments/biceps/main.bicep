@description('Define the project name or prefix for all objects.')
@minLength(1)
@maxLength(11)
param projectName string = 'contoso'

@description('The Enrollment group primary key')
@secure()
param primaryKey string

@description('The Enrollment group secondary key')
@secure()
param secondaryKey string

param location string = resourceGroup().location

module StorageAccount 'storage.bicep' = {
  name: 'storage'
  params: {
    projectName: projectName
    location: location
  }
}

module IoT 'hub-dps.bicep' = {
  name: 'iot'
  params: {
    storageAccountName: StorageAccount.outputs.AccountName
    storageId: StorageAccount.outputs.AccountId
    primaryKey: primaryKey
    secondaryKey: secondaryKey
    location: location
  }
}

module SqlServer 'sql-server.bicep' = {
  name: 'sql'
  params: {
    projectName: projectName
    location: location
  }
}

module Function 'function.bicep' = {
  name: 'func'
  params: {
    location: location
    iothubEventHubCS: IoT.outputs.EventHubCS
    iothubOwnerCS: IoT.outputs.HubOwnerCS
    sqlDatabase: SqlServer.outputs.sqlDatabase
    sqlEndpoint: SqlServer.outputs.sqlEndpoint
    storageId: StorageAccount.outputs.AccountId
    storageAccountName: StorageAccount.outputs.AccountName
    projectName: projectName
  }
}
