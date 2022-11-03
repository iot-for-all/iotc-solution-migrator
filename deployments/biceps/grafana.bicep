
@description('The project name to be used for naming generation')
param projectName string

param location string = resourceGroup().location
param identity object

var name= take('${projectName}dash${uniqueString(resourceGroup().id)}', 20)

resource grafana 'Microsoft.Dashboard/grafana@2022-08-01' = {
  name: name
  location: location
  sku: {
    name: 'Standard'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.Id}': {}
    }
  }
  properties: {
    apiKey: 'Disabled'
    deterministicOutboundIP: 'Disabled'
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
  }
}
