@description('Define the project name or prefix for all objects.')
@minLength(1)
@maxLength(11)
param projectName string = 'contoso'

var ownerRoleId = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
var userId = take('${projectName}id${uniqueString(resourceGroup().id)}', 20)
var ownerRoleAssignment = guid(userId, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', ownerRoleId))

resource UserIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: userId
  location: resourceGroup().location
}

resource UserIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: UserIdentity
  name: ownerRoleAssignment
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', ownerRoleId)
    principalId: UserIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output id string = UserIdentity.id
output principalId string = UserIdentity.properties.principalId
