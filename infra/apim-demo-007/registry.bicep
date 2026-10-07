// Shared container registry for the APIM 007 demo backends. Admin user and anonymous pull are disabled.

@description('Azure region where the registry will be deployed')
param location string = resourceGroup().location

@description('Object ID of the service principal that builds and pushes backend images; granted AcrPush on the registry')
@minLength(36)
@maxLength(36)
param pushPrincipalId string

var registryName = 'crapimdemo007${uniqueString(resourceGroup().id)}'
var acrPushRoleId = '8311e382-0749-4cb8-b61a-304f252e45ec'

var tags = {
  apimDemo: '007'
  environment: 'shared'
  owner: 'apim-demo-007'
}

resource registry 'Microsoft.ContainerRegistry/registries@2025-04-01' = {
  name: registryName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    anonymousPullEnabled: false
  }
}

resource pushRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, pushPrincipalId, acrPushRoleId)
  scope: registry
  properties: {
    principalId: pushPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPushRoleId)
    principalType: 'ServicePrincipal'
  }
}

output registryName string = registry.name
output registryLoginServer string = registry.properties.loginServer
output registryId string = registry.id
