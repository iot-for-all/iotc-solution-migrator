@description('Define the project name or prefix for all objects.')
@minLength(1)
@maxLength(11)
param projectName string = 'contoso'

@description('The storage account name.')
param storageAccountName string

@description('The storage account name.')
@secure()
param storageAccountKey string

@description('Repository url.')
param repoUrl string = 'https://github.com/iot-for-all/iotc-solution-migrator.git'

@description('Repository branch.')
param functionBranch string = 'main'

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

var hostingName = '${projectName}host${uniqueString(resourceGroup().id)}'
var functionName = '${projectName}fn${uniqueString(resourceGroup().id)}'
var location = resourceGroup().location

resource hostingPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: hostingName
  location: location
  sku: {
    tier: 'Dynamic'
    name: 'Y1'
  }
}

resource azureFunction 'Microsoft.Web/sites@2022-03-01' = {
  name: functionName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: hostingPlan.id
    siteConfig: {
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
          value: '~2'
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
  resource functionCodeDeploy 'sourcecontrols' = {
    name: 'web'
    properties: {
      repoUrl: repoUrl
      branch: functionBranch
      isManualIntegration: true
    }
  }
}
