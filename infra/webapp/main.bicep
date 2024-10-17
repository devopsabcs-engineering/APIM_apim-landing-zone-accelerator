@description('Base name of the resource such as web app name and app service plan ')
@minLength(2)
param appName string = 'app-${baseName}-${uniqueString(resourceGroup().id)}'

@description('The SKU of App Service Plan ')
param sku string = 'F1' // 'S1'

@description('The Runtime stack of current web app')
param linuxFxVersion string = 'DOTNETCORE|8.0' // 'php|7.4'

@description('Location for all resources.')
param location string = resourceGroup().location

param baseName string = 'soap-api'

param appInsightsName string = 'appi-${baseName}-${uniqueString(resourceGroup().id)}'
param appServicePlanName string = 'asp-${baseName}-${uniqueString(resourceGroup().id)}'
param logAnalyticsName string = 'log-${baseName}-${uniqueString(resourceGroup().id)}'

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: sku
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource appService 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      ftpsState: 'FtpsOnly'
    }
    httpsOnly: true
  }
  identity: {
    type: 'SystemAssigned'
  }
  resource basicPublishingCredentialsPolicies 'basicPublishingCredentialsPolicies@2023-12-01' = {
    name: 'scm'
    //kind: 'string'
    properties: {
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
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

output appServiceId string = appService.id
output appInsightsId string = appInsights.id
