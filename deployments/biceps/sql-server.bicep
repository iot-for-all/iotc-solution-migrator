@description('Define the project name or prefix for all objects.')
@minLength(1)
@maxLength(11)
param projectName string = 'contoso'

param location string = resourceGroup().location

@description('The user managed identity id')
param identity object

var serverName = take('${projectName}sql${uniqueString(resourceGroup().id)}', 20)
var databaseName = 'solutiondb'
var adminLoginUsername = 'solutionsqladmin'
var adminLoginPassword = '${toUpper(take(projectName, 4))}_${take(uniqueString(resourceGroup().id), 8)}@'

resource SqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  location: location
  name: serverName
  properties: {
    administratorLogin: adminLoginUsername
    administratorLoginPassword: adminLoginPassword
    // administrators: {
    //   login: identity.name
    //   administratorType: 'ActiveDirectory'
    //   azureADOnlyAuthentication: false
    //   principalType: 'Application'
    //   sid: identity.clientId
    //   tenantId: subscription().tenantId
    // }
    minimalTlsVersion: '1.2'
    restrictOutboundNetworkAccess: 'Disabled'
    publicNetworkAccess: 'Enabled'
    version: '12.0'
  }

  resource Database 'databases@2022-05-01-preview' = {
    location: location
    name: databaseName
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${identity.Id}': {}
      }
    }
    sku: {
      name: 'GP_S_Gen5'
      tier: 'GeneralPurpose'
      capacity: 1
      family: 'Gen5'
    }
  }
  resource FirewallRule1 'firewallRules@2022-05-01-preview' = {
    name: 'AllowAllWindowsAzureIps'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }
  resource FirewallRule2 'firewallRules@2022-05-01-preview' = {
    name: 'AllowAll-Unsafe'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '255.255.255.255'
    }
  }
}

output sql object={
  Endpoint: SqlServer.properties.fullyQualifiedDomainName
  Database: databaseName
  Username: adminLoginUsername
  Password: adminLoginPassword
}

