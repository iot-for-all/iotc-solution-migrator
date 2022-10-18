@description('Define the project name or prefix for all objects.')
@minLength(1)
@maxLength(11)
param projectName string = 'contoso'

param location string = resourceGroup().location

var serverName = '${projectName}sql${uniqueString(resourceGroup().id)}'
var databaseName = 'solutiondb'

resource SqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  location: location
  name: serverName
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    administratorLogin: 'solutionsqladmin'
    administratorLoginPassword: 'solutionsqladmin'
    administrators: {

    }
    minimalTlsVersion: '1.2'
    restrictOutboundNetworkAccess: 'Disabled'
    publicNetworkAccess: 'Enabled'
    version: '12.0'
  }
}

resource Database 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  location: location
  name: databaseName
  sku: {
    name: 'GP_S_Gen5'
    tier: 'GeneralPurpose'
    capacity: 1
    family: 'Gen5'
  }
}

output sqlEndpoint string = SqlServer.properties.fullyQualifiedDomainName
output sqlDatabase string = Database.name
