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

var dpsScript = take('${projectName}dps${uniqueString(resourceGroup().id)}script', 20)
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
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: StorageAccount.name
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: UserIdentity.name
}

resource userIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: 'roleAssignment'
}

module IoT 'hub-dps.bicep' = {
  name: 'iot'
  params: {
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
    // userIdentityId: UserIdentity.id
  }
}

resource SetupScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  kind: 'AzureCLI'
  location: location
  name: dpsScript
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    storageAccountSettings: {
      storageAccountKey: storage.listKeys().keys[0].value
      storageAccountName: StorageAccount.outputs.AccountName
    }
    azCliVersion: '2.40.0'
    cleanupPreference: 'OnSuccess'
    timeout: 'PT30M'
    retentionInterval: 'P1D'
    scriptContent: 'az config set extension.use_dynamic_install=yes_without_prompt && az login --identity && az iot dps enrollment-group create -g ${resourceGroup().name} --dps-name ${IoT.outputs.DPSName} --enrollment-id ${enrollmentGroupId} --primary-key ${primaryKey} --secondary-key ${secondaryKey} --subscription ${subscription().subscriptionId}'
  }
  dependsOn: [
    StorageAccount
    userIdentityRoleAssignment
    IoT
    SqlServer
    Function
  ]
}
