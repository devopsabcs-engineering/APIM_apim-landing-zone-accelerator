// APIM 007 demo instance. Derived from infra/api-management-basicv2/main.bicep without Key Vault or OAuth2 server.

@description('Environment name')
@allowed([
  'dev'
  'prod'
])
param environmentName string

@description('Instance number used in resource names')
param instanceNumber string = '007'

@description('Azure region where the resources will be deployed')
param location string = resourceGroup().location

@description('The email address of the owner of the service')
@minLength(1)
param publisherEmail string

@description('The name of the owner of the service')
@minLength(1)
param publisherName string

@description('The pricing tier of this API Management service')
@allowed([
  'BasicV2'
])
param sku string = 'BasicV2'

@description('Object ID of the release service principal; granted API Management Service Contributor on the instance and Reader on the resource group')
@minLength(36)
@maxLength(36)
param releasePrincipalId string

var applicationInsightsLoggerName = 'apimlogger'
var baseName = 'apim-${environmentName}-${instanceNumber}-${uniqueString(resourceGroup().id)}'
var apiManagementName = baseName
var applicationInsightsName = 'appi-${baseName}'
var logAnalyticsWorkspaceName = 'log-${baseName}'

var tags = {
  apimDemo: '007'
  environment: environmentName
  owner: 'apim-demo-007'
}

var apimServiceContributorRoleId = '312a565d-c81f-4fd8-895a-4e21e48d571c'
var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'

resource apiManagement 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: apiManagementName
  location: location
  tags: tags
  sku: {
    name: sku
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    apiVersionConstraint: {
      minApiVersion: '2019-12-01'
    }
    publisherEmail: publisherEmail
    publisherName: publisherName
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'true'
    }
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    workspaceCapping: {
      dailyQuotaGb: 1
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    #disable-next-line BCP037
    CustomMetricsOptedInType: 'WithDimensions'
  }
}

// Bicep-owned; the APIops bundle must not manage this named value or the logger.
resource namedValueAppInsightsSecret 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apiManagement
  name: 'instrumentationKey'
  properties: {
    tags: []
    secret: true
    displayName: 'instrumentationKey'
    value: applicationInsights.properties.InstrumentationKey
  }
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2024-06-01-preview' = {
  parent: apiManagement
  name: applicationInsightsLoggerName
  properties: {
    resourceId: applicationInsights.id
    description: 'Application Insights for APIM'
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: '{{${namedValueAppInsightsSecret.name}}}'
    }
  }
}

// Bicep-owned; llm-emit-token-metric needs metrics enabled. Bodies are never logged.
resource apimDiagnostic 'Microsoft.ApiManagement/service/diagnostics@2024-06-01-preview' = {
  parent: apiManagement
  name: 'applicationinsights'
  properties: {
    loggerId: apimLogger.id
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    verbosity: 'information'
    logClientIp: false
    metrics: true
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: { body: { bytes: 0 } }
      response: { body: { bytes: 0 } }
    }
    backend: {
      request: { body: { bytes: 0 } }
      response: { body: { bytes: 0 } }
    }
  }
}

resource releaseApimContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(apiManagement.id, releasePrincipalId, apimServiceContributorRoleId)
  scope: apiManagement
  properties: {
    principalId: releasePrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', apimServiceContributorRoleId)
    principalType: 'ServicePrincipal'
  }
}

resource releaseResourceGroupReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, releasePrincipalId, readerRoleId)
  properties: {
    principalId: releasePrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
    principalType: 'ServicePrincipal'
  }
}

output apimName string = apiManagement.name
output apimId string = apiManagement.id
output apimGatewayUrl string = apiManagement.properties.gatewayUrl
output location string = location
output resourceGroupId string = resourceGroup().id
output applicationInsightsId string = applicationInsights.id
output loggerId string = apimLogger.id
output diagnosticId string = apimDiagnostic.id
