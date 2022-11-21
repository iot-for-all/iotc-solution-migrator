@description('Define the project name or prefix for all objects.')
@minLength(1)
@maxLength(11)
param projectName string = 'contoso'

@description('The Azure IoT Central app subdomain')
param iotcAppSubdomain string

@description('The Azure IoT Central API Key')
@secure()
param iotcApiKey string

var location = resourceGroup().location

var enrollmentGroupId = take('${projectName}dps${uniqueString(resourceGroup().id)}eg', 20)

module UserIdentity 'identity.bicep' = {
  name: 'identity'
  params: {
    projectName: projectName
  }
}

module StorageAccount 'storage.bicep' = {
  name: 'storage'
  params: {
    projectName: projectName
    location: location
    identityId: UserIdentity.outputs.id
  }
  dependsOn: [
    UserIdentity
  ]
}

module IoT 'hub-dps.bicep' = {
  name: 'iot'
  params: {
    location: location
    projectName: projectName
  }
  dependsOn: [
    UserIdentity
  ]
}

module SqlServer 'sql-server.bicep' = {
  name: 'sql'
  params: {
    projectName: projectName
    location: location
    identity: {
      name: UserIdentity.outputs.name
      clientId: UserIdentity.outputs.clientId
      principalId: UserIdentity.outputs.principalId
      Id: UserIdentity.outputs.id
    }
  }
  dependsOn: [
    UserIdentity
    IoT
  ]
}

module Function 'function_user.bicep' = {
  name: 'func'
  params: {
    location: location
    iothubEventHubCS: IoT.outputs.EventHubCS
    iothubOwnerCS: IoT.outputs.HubOwnerCS
    sql: SqlServer.outputs.sql
    storageId: StorageAccount.outputs.AccountId
    storageAccountName: StorageAccount.outputs.AccountName
    projectName: projectName
  }
  dependsOn: [
    UserIdentity
    IoT
    StorageAccount
    SqlServer
  ]
}

module Grafana 'grafana.bicep' = {
  name: 'grafana'
  params: {
    projectName: projectName
    location: location
    identity: {
      Id: UserIdentity.outputs.id
      clientId: UserIdentity.outputs.clientId
    }
  }
  dependsOn: [
    UserIdentity
    SqlServer
  ]
}

module SetupScript 'script.bicep' = {
  name: 'script'
  params: {
    functionName: Function.outputs.FunctionName
    identity: {
      Id: UserIdentity.outputs.id
      name: UserIdentity.outputs.name
    }
    storageAccountKey: StorageAccount.outputs.AccountKey
    storageAccountName: StorageAccount.outputs.AccountName
    projectName: projectName
    dpsResourceName: IoT.outputs.DPSName
    functionUrl: Function.outputs.FunctionUrl
    iotcApiKey: iotcApiKey
    iotcAppUrl: 'https://${iotcAppSubdomain}.azureiotcentral.com'
    sqlDatabase: SqlServer.outputs.sql.Database
    sqlEndpoint: SqlServer.outputs.sql.Endpoint
    sqlUserName: SqlServer.outputs.sql.Username
    sqlPassword: SqlServer.outputs.sql.Password
    eventHubName: IoT.outputs.EventHubName
    grafanaEndpoint: Grafana.outputs.endpoint
  }
  dependsOn: [
    StorageAccount
    UserIdentity
    IoT
    SqlServer
    Function
  ]
}

output FunctionUrl string = Function.outputs.FunctionUrl
output ScopeId string = IoT.outputs.ScopeId
