@description('Define the project name or prefix for all objects.')
@minLength(1)
@maxLength(11)
param projectName string = 'contoso'

var ownerRoleId = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
var grafanaAdminRoleId = '22926164-76b3-42b3-bc55-97df8dab3e41'
var userId = take('${projectName}id${uniqueString(resourceGroup().id)}', 20)
var ownerRoleAssignment = guid(userId, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', ownerRoleId))
var rgRoleAssignment = guid(resourceGroup().name, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', ownerRoleId))
var grafanaRoleAssignment = guid(resourceGroup().name, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', grafanaAdminRoleId))

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

resource UserIdentityResourceGroupAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: rgRoleAssignment
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', ownerRoleId)
    principalId: UserIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource UserIdentityGrafanaAdmin 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: grafanaRoleAssignment
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', grafanaAdminRoleId)
    principalId: UserIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output id string = UserIdentity.id
output name string = UserIdentity.name
output principalId string = UserIdentity.properties.principalId
output clientId string = UserIdentity.properties.clientId
