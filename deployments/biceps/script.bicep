param identity object

param sqlEndpoint string
param sqlDatabase string
param functionName string
param tables array = []

param projectName string = 'contoso'

@secure()
param storageAccountKey string
param storageAccountName string

@metadata({
})
param dpsEnrollment object

resource SetupScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  kind: 'AzurePowerShell'
  location: resourceGroup().location
  name: '${projectName}-configscript'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.Id}': {}
    }
  }
  properties: {
    storageAccountSettings: {
      storageAccountKey: storageAccountKey
      storageAccountName: storageAccountName
    }
    azPowerShellVersion: '8.3'
    cleanupPreference: 'OnExpiration'
    timeout: 'PT30M'
    retentionInterval: 'P1D'
    primaryScriptUri: 'https://raw.githubusercontent.com/lucadruda/iotc-solution-migrator/main/deployments/scripts/config.ps1'
    environmentVariables: [
      {
        name: 'SUBSCRIPTION_ID'
        value: subscription().subscriptionId
      }
      {
        name: 'FUNCTIONAPP_NAME'
        value: functionName
      }
      {
        name: 'REPO_URL'
        value: 'https://github.com/lucadruda/iotc-solution-migrator'
      }
      {
        name: 'REPO_BRANCH'
        value: 'main'
      }
      {
        name: 'TABLES'
        value: string(tables)
      }
      {
        name: 'DPS_ENROLLMENT_NAME'
        value: dpsEnrollment.enrollmentName
      }
      {
        name: 'DPS_RESOURCE_NAME'
        value: dpsEnrollment.resourceName
      }
      {
        name: 'DPS_ENROLLMENT_PRIMARY_KEY'
        value: dpsEnrollment.primaryKey
      }
      {
        name: 'DPS_ENROLLMENT_SECONDARY_KEY'
        value: dpsEnrollment.secondaryKey
      }
      {
        name: 'IDENTITY_NAME'
        value: identity.name
      }
      {
        name: 'SQL_ENDPOINT'
        value: sqlEndpoint
      }
      {
        name: 'SQL_DATABASE'
        value: sqlDatabase
      }
    ]
  }
}
