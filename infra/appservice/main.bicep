// deploy bicep file - app service plan, app service, app insights, container registry

param location string = resourceGroup().location
param baseName string = 'weather-api'
param appName string = 'app-${baseName}-${uniqueString(resourceGroup().id)}'
param appInsightsName string = 'appi-${baseName}-${uniqueString(resourceGroup().id)}'
param appServicePlanName string = 'asp-${baseName}-${uniqueString(resourceGroup().id)}'
param containerRegistryName string = substring(
  replace('cr${baseName}${uniqueString(resourceGroup().id)}', '-', ''),
  0,
  min(24, length(replace('cr${baseName}${uniqueString(resourceGroup().id)}', '-', '')))
)
param logAnalyticsName string = 'log-${baseName}-${uniqueString(resourceGroup().id)}'
param imageName string = 'weatherapi'
param addStorageAccount bool = false
param storageAccountName string = replace('st${baseName}${uniqueString(resourceGroup().id)}', '-', '')
param containerName string = 'somecontainer'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = if (addStorageAccount) {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  // add blob service to the storage account
  resource blobServices 'blobServices@2023-05-01' = {
    name: 'default'
    properties: {}
    // add a container to the storage account
    resource container 'containers@2023-05-01' = {
      name: containerName
      properties: {}
    }
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  properties: {
    reserved: true
  }
  sku: {
    name: 'B1' // 'F1'
    tier: 'Basic' // 'Free'
  }
  kind: 'linux'
}

param addAzureAdAppSettings bool = false
param azureAdDomain string = 'MngEnvMCAP675646.onmicrosoft.com'
param azureAdClientId string = 'b72949d1-b1f4-41cc-a370-5fa5f4e40d10'
@secure() // secure the client secret
param azureAdClientSecret string = ''

var azureAdAppSettings = [
  {
    name: 'AzureAd__Instance'
    value: environment().authentication.loginEndpoint
  }
  {
    name: 'AzureAd__Domain'
    value: azureAdDomain
  }
  {
    name: 'AzureAd__TenantId'
    value: tenant().tenantId
  }
  {
    name: 'AzureAd__ClientId'
    value: azureAdClientId
  }
  {
    name: 'AzureAd__CallbackPath'
    value: '/signin-oidc'
  }
  {
    name: 'AzureAd__SignedOutCallbackPath'
    value: '/signout-callback-oidc'
  }
  {
    name: 'AzureAd__ClientSecret'
    value: azureAdClientSecret
  }
  {
    name: 'GraphApiUrl'
    value: 'https://graph.microsoft.com'
  }
  {
    name: 'AzureStorage__BaseUrl'
    value: 'https://${storageAccount.name}.blob.${environment().suffixes.storage}'
  }
  {
    name: 'AzureStorage__ContainerName'
    value: containerName
  }
]

var baseAppSettings = [
  {
    name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
    value: appInsights.properties.InstrumentationKey
  }
  {
    name: 'Logging__LogLevel__Default'
    value: 'Information'
  }
  {
    name: 'Logging__LogLevel__Microsoft.AspNetCore'
    value: 'Warning'
  }
  {
    name: 'Logging__ApplicationInsights__LogLevel__Default'
    value: 'Debug'
  }
  {
    name: 'Logging__ApplicationInsights__LogLevel__Microsoft'
    value: 'Error'
  }
  {
    name: 'AllowedHosts'
    value: '*'
  }
  {
    name: 'ApplicationInsights__InstrumentationKey'
    value: appInsights.properties.InstrumentationKey
  }
  {
    name: 'ApplicationInsights__ConnectionString'
    value: appInsights.properties.ConnectionString
  }
  {
    name: 'DOCKER_ENABLE_CI'
    value: 'true'
  }
  {
    name: 'DOCKER_REGISTRY_SERVER_URL'
    value: containerRegistry.properties.loginServer
  }
  {
    name: 'DOCKER_REGISTRY_SERVER_USERNAME'
    value: containerRegistry.listCredentials().username
  }
  {
    name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
    value: containerRegistry.listCredentials().passwords[0].value
  }
  {
    name: 'APPINSIGHTS_PROFILERFEATURE_VERSION'
    value: '1.0.0'
  }
  {
    name: 'APPINSIGHTS_SNAPSHOTFEATURE_VERSION'
    value: '1.0.0'
  }
  {
    name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
    value: '~3'
  }
  {
    name: 'DiagnosticServices_EXTENSION_VERSION'
    value: '~3'
  }
  {
    name: 'InstrumentationEngine_EXTENSION_VERSION'
    value: 'disabled'
  }
  {
    name: 'SnapshotDebugger_EXTENSION_VERSION'
    value: 'disabled'
  }
  {
    name: 'XDT_MicrosoftApplicationInsights_BaseExtensions'
    value: 'disabled'
  }
  {
    name: 'XDT_MicrosoftApplicationInsights_Mode'
    value: 'recommended'
  }
  {
    name: 'XDT_MicrosoftApplicationInsights_PreemptSdk'
    value: 'disabled'
  }
  {
    name: 'APPLICATIONINSIGHTS_CONFIGURATION_CONTENT'
    value: ''
  }
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: appInsights.properties.ConnectionString
  }
]

// if addAzureAdAppSettings is true, add azure ad app settings to the base app settings
// otherwise, use only the base app settings
var appSettings = addAzureAdAppSettings ? union(baseAppSettings, azureAdAppSettings) : baseAppSettings

resource appService 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerRegistry.name}.azurecr.io/${imageName}:latest'
      appSettings: appSettings
    }
    httpsOnly: true
  }

  //enable basic auth for the app
  identity: {
    type: 'SystemAssigned'
  }

  resource scm 'basicPublishingCredentialsPolicies@2023-12-01' = {
    name: 'scm'
    properties: {
      //enable basic auth for the app
      allow: true
    }
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      legacy: 0 // 0 means disable
      searchVersion: 1
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  // enable admin user
  properties: {
    adminUserEnabled: true
  }
}

output appServiceId string = appService.id
output appInsightsId string = appInsights.id
output containerRegistryId string = containerRegistry.id
output appName string = appService.name
output containerRegistryName string = containerRegistry.name
