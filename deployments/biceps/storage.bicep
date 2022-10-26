@description('Define the project name or prefix for all objects.')
@minLength(1)
@maxLength(11)
param projectName string = 'contoso'

var accountName = take('${projectName}sa${uniqueString(resourceGroup().id)}', 20)
param location string = resourceGroup().location
@description('The user managed identity id')
param identityId string

resource StorageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: accountName
  location: location
  identity:{
    type:'SystemAssigned,UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
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
output AccountId string = StorageAccount.id
