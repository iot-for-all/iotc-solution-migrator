param sqlAdministratorLogin string

@secure()
param sqlAdministratorLoginPassword string

var apiVersions = {
  sqlserver: '2021-02-01-preview'
}
var names = {
  sqlserverName: 'iotcsolutionsql'
  databaseName: 'iotcsolutiondb'
}

resource names_sqlserver 'Microsoft.Sql/servers@[variables(\'apiVersions\').sqlserver]' = {
  name: names.sqlserverName
  location: resourceGroup().location
  tags: {
    displayName: 'SQL Server'
  }
  properties: {
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorLoginPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    restrictOutboundNetworkAccess: 'Disabled'
  }
}

resource names_sqlserverName_names_database 'Microsoft.Sql/servers/databases@[variables(\'apiVersions\').sqlserver]' = {
  name: '${names.sqlserverName}/${names.databaseName}'
  location: resourceGroup().location
  tags: {
    displayName: 'Database'
  }
  sku: {
    name: 'GP_S_Gen5'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 1
  }
  kind: 'v12.0,user,vcore,serverless'
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 1073741824
  }
  dependsOn: [
    names_sqlserver
  ]
}

resource names_sqlserverName_AllowAllWindowsAzureIps 'Microsoft.Sql/servers/firewallRules@[variables(\'apiVersions\').sqlserver]' = {
  name: '${names.sqlserverName}/AllowAllWindowsAzureIps'
  dependsOn: [
    names_sqlserver
  ]
}