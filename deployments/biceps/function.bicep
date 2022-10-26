@description('Define the project name or prefix for all objects.')
@minLength(1)
@maxLength(11)
param projectName string = 'contoso'

@description('The storage account name.')
param storageAccountName string

@description('The storage resource Id')
param storageId string

@description('Sql server endpoint.')
param sqlEndpoint string

@description('Sql server database.')
param sqlDatabase string

@description('IoTHub EventHub endpoint Connection string.')
@secure()
param iothubEventHubCS string

@description('IoTHub Owner connection string.')
@secure()
param iothubOwnerCS string

@description('The user managed identity id')
param identityId string

var hostingName = take('${projectName}host${uniqueString(resourceGroup().id)}', 20)
var functionName = take('${projectName}fn${uniqueString(resourceGroup().id)}', 20)
// var configScript = take('${projectName}fnscript${uniqueString(resourceGroup().id)}', 20)
var storageAccountKey = listKeys(storageId, '2022-05-01').keys[0].value

param location string = resourceGroup().location
// param userIdentityId string

resource hostingPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: hostingName
  location: location
  kind: 'functionapp,linux'
  sku: {
    tier: 'Dynamic'
    name: 'Y1'
    size: 'Y1'
    family: 'Y1'
    capacity: 0
  }
  properties: {
    reserved: true // Mandatory for linux
  }
}

resource azureFunction 'Microsoft.Web/sites@2022-03-01' = {
  name: functionName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    httpsOnly: true
    serverFarmId: hostingPlan.id
    isXenon: false
    hyperV: false
    siteConfig: {
      linuxFxVersion: 'node|16'
      cors: {
        allowedOrigins: [
          '*'
        ]
        supportCredentials: false
      }
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccountKey}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccountKey}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~16'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'SQL_ENDPOINT'
          value: sqlEndpoint
        }
        {
          name: 'SQLDatabase'
          value: sqlDatabase
        }
        { name: 'IoTHubEventHubCS'
          value: iothubEventHubCS
        }
        {
          name: 'IoTHubOwnerCS'
          value: iothubOwnerCS
        }
      ]
      minTlsVersion: '1.2'
    }
  }
  // resource functionCodeDeploy 'sourcecontrols' = {
  //   name: 'web'
  //   properties: {
  //     repoUrl: repoUrl
  //     branch: functionBranch
  //     isManualIntegration: true
  //   }
  // }
}

var funcKey = listKeys('${azureFunction.id}/host/default', azureFunction.apiVersion).functionKeys.default
output FunctionName string = azureFunction.name
output FunctionUrl string = 'https://${azureFunction.properties.defaultHostName}/api/ModelParser?code=${funcKey}'
