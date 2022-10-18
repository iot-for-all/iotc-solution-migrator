@description('Define the project name or prefix for all objects.')
@minLength(1)
@maxLength(11)
param projectName string = 'contoso'

var accountName = '${projectName}sa${uniqueString(resourceGroup().id)}'
var location = resourceGroup().location

resource StorageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: accountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  resource FileShare 'fileServices@2022-05-01' = {
    name: 'default'
    resource tables 'shares@2022-05-01' = {
      name: 'tables'
    }
  }
}

output AccountName string = accountName
output PrimaryKey string = StorageAccount.listKeys().keys[0].value
