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

module StorageAccount 'storage.bicep' = {
  name: 'storage'
  params: {
    projectName: projectName
  }
}

module IoT 'hub-dps.bicep' = {
  name: 'iot'
  params: {
    storageAccountName: StorageAccount.outputs.AccountName
    storagePrimaryKey: StorageAccount.outputs.PrimaryKey
    primaryKey: primaryKey
    secondaryKey: secondaryKey
  }
}

module SqlServer 'sql-server.bicep' = {
  name: 'sql'
  params: {
    projectName: projectName
  }
}

module Function 'function.bicep' = {
  name: 'func'
  params: {
    iothubEventHubCS: IoT.outputs.EventHubCS
    iothubOwnerCS: IoT.outputs.HubOwnerCS
    sqlDatabase: SqlServer.outputs.sqlDatabase
    sqlEndpoint: SqlServer.outputs.sqlEndpoint
    storageAccountKey: StorageAccount.outputs.PrimaryKey
    storageAccountName: StorageAccount.outputs.AccountName
    projectName: projectName
  }
}
