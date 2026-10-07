// APIM 007 AI Gateway resources: Foundry model account with one chat deployment, Content Safety,
// and the role assignments APIM needs to call them with its system-assigned managed identity.

@description('Environment name')
@allowed([
  'dev'
  'prod'
])
param environmentName string

@description('Region for the AI accounts (regional Standard deployments keep data in Canada)')
param aiLocation string = 'canadaeast'

@description('Name of the existing APIM 007 service in this resource group')
param apimName string

@description('Chat model name')
param chatModelName string

@description('Chat model version')
param chatModelVersion string

@description('Deployment SKU; only regional Standard is allowed')
param chatSkuName string = 'Standard'

@description('Deployment capacity in thousands of tokens per minute')
@minValue(1)
@maxValue(50)
param chatCapacity int = 10

@description('Principal IDs (service principals) that create the Content Safety blocklist through the data plane')
param blocklistWriterPrincipalIds array = []

var suffix = uniqueString(resourceGroup().id)
var aiServicesName = 'ais-apim007-${environmentName}-${suffix}'
var contentSafetyName = 'cs-apim007-${environmentName}-${suffix}'
var chatDeploymentName = 'chat'
var cognitiveServicesOpenAIUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
var cognitiveServicesUserRoleId = 'a97b65f3-24c7-4388-baec-2e87135dc908'
var tags = {
  apimDemo: '007'
  environment: environmentName
  owner: 'apim-demo-007'
}

var skuGuard = chatSkuName == 'Standard' ? chatSkuName : fail('Only the regional Standard deployment SKU is allowed (data residency).')

resource apiManagement 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

resource aiServices 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: aiServicesName
  location: aiLocation
  tags: tags
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: aiServicesName
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }
}

resource chatDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: aiServices
  name: chatDeploymentName
  sku: {
    name: skuGuard
    capacity: chatCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: chatModelName
      version: chatModelVersion
    }
    versionUpgradeOption: 'NoAutoUpgrade'
  }
}

resource contentSafety 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: contentSafetyName
  location: aiLocation
  tags: tags
  kind: 'ContentSafety'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: contentSafetyName
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }
}

resource apimOpenAIUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiServices.id, apiManagement.id, cognitiveServicesOpenAIUserRoleId)
  scope: aiServices
  properties: {
    principalId: apiManagement.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAIUserRoleId)
    principalType: 'ServicePrincipal'
  }
}

resource apimContentSafetyUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(contentSafety.id, apiManagement.id, cognitiveServicesUserRoleId)
  scope: contentSafety
  properties: {
    principalId: apiManagement.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesUserRoleId)
    principalType: 'ServicePrincipal'
  }
}

resource blocklistWriters 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in blocklistWriterPrincipalIds: {
  name: guid(contentSafety.id, principalId, cognitiveServicesUserRoleId)
  scope: contentSafety
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesUserRoleId)
    principalType: 'ServicePrincipal'
  }
}]

output aiServicesId string = aiServices.id
output aiServicesEndpoint string = 'https://${aiServicesName}.openai.azure.com/'
output contentSafetyId string = contentSafety.id
output contentSafetyEndpoint string = contentSafety.properties.endpoint
output chatDeploymentName string = chatDeployment.name
output chatModel string = '${chatModelName}:${chatModelVersion}:${chatSkuName}:${chatCapacity}'
