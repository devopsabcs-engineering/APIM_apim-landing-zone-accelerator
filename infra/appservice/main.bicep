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

resource appService 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerRegistry.name}.azurecr.io/${imageName}:latest'
      appSettings: [
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
      ]
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
