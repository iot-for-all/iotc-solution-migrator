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

var location = resourceGroup().location

@description('List of table names')
param tables array = []

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

// resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
//   name: StorageAccount.name
// }

// resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
//   name: UserIdentity.name
// }

// resource userIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
//   name: 'roleAssignment'
// }

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
    identitySID: UserIdentity.outputs.principalId
  }
  dependsOn: [
    UserIdentity
    IoT
  ]
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
    identityId: UserIdentity.outputs.id
  }
  dependsOn: [
    UserIdentity
    IoT
    StorageAccount
    SqlServer
  ]
}

module SetupScript 'script.bicep' = {
  name: 'script'
  params: {
    functionName: Function.outputs.FunctionName
    identityId: UserIdentity.outputs.id
    storageAccountKey: StorageAccount.outputs.AccountKey
    storageAccountName: StorageAccount.outputs.AccountName
    projectName: projectName
    tables: tables
    dpsEnrollment: {
      resourceName: IoT.outputs.DPSName
      enrollmentName: enrollmentGroupId
      primaryKey: primaryKey
      secondaryKey: secondaryKey
    }
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
