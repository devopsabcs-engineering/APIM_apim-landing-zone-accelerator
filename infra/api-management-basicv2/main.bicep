@description('The email address of the owner of the service')
@minLength(1)
param publisherEmail string = 'contoso@contoso.com'

@description('The name of the owner of the service')
@minLength(1)
param publisherName string = 'apimPublisher'

@description('The pricing tier of this API Management service')
@allowed([
  'BasicV2'
  'StandardV2'
])
param sku string = 'BasicV2'

@description('The instance size of this API Management service.')
param skuCount int = 1

@description('Azure region where the resources will be deployed')
param location string = resourceGroup().location

@description('Environment Name')
@allowed([
  'dev'
  'qa'
  'prod'
])
param environmentName string

param instanceNumber string

@description('Whether to create an OAuth2 authorization server for the developer portal')
param createOAuth2Server bool = false

@description('The client ID of the AAD app registration for OAuth2 authorization')
param oAuth2ClientId string = ''

var applicationInsightsLoggerName = 'apimlogger'
var baseName = 'apim-${environmentName}-${instanceNumber}-${uniqueString(resourceGroup().id)}'
var apiManagementName = baseName
var applicationInsightsName = 'appi-${baseName}'
var logAnalyticsWorkspaceName = 'log-${baseName}'
var keyVaultName = substring('kv-${baseName}', 0, 24)

resource apiManagement 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: apiManagementName
  location: location
  sku: {
    name: sku
    capacity: skuCount
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
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

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
      instrumentationKey: '{{instrumentationKey}}'
    }
  }
  dependsOn: [
    namedValueAppInsightsSecret
  ]
}

resource keyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    sku: {
      name: 'standard'
      family: 'A'
    }
    tenantId: tenant().tenantId
  }
}

resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().subscriptionId, keyVaultName, apiManagement.name)
  scope: keyVault
  properties: {
    principalId: apiManagement.identity.principalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'
    )
  }
}

resource secretAppInsights 'Microsoft.KeyVault/vaults/secrets@2024-04-01-preview' = {
  name: 'AppInsightsKeyApim'
  parent: keyVault
  properties: {
    value: applicationInsights.properties.InstrumentationKey
  }
}

resource oAuth2Server 'Microsoft.ApiManagement/service/authorizationServers@2024-06-01-preview' = if (createOAuth2Server && oAuth2ClientId != '') {
  parent: apiManagement
  name: 'weatherappoauth'
  properties: {
    displayName: 'Weather App OAuth'
    clientRegistrationEndpoint: environment().authentication.loginEndpoint
    authorizationEndpoint: '${environment().authentication.loginEndpoint}${tenant().tenantId}/oauth2/v2.0/authorize'
    tokenEndpoint: '${environment().authentication.loginEndpoint}${tenant().tenantId}/oauth2/v2.0/token'
    clientId: oAuth2ClientId
    grantTypes: [
      'authorizationCode'
    ]
    authorizationMethods: [
      'GET'
      'POST'
    ]
  }
}

output apiManagementName string = apiManagement.name
output apiManagementGatewayUrl string = apiManagement.properties.gatewayUrl
output applicationInsightsName string = applicationInsights.name
output keyVaultName string = keyVault.name
output resourceGroupName string = resourceGroup().name
