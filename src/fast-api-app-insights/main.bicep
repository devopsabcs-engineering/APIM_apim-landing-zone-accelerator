param appName string
param location string = resourceGroup().location
param appInsightsName string = '${appName}-ai'
param serverFarmName string = '${appName}-plan'
param skuName string = 'B1'
param skuTier string = 'Basic'
param skuCapacity int = 1

var runtime = 'PYTHON|3.13'

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: serverFarmName
  location: location
  kind: 'app,linux'
  sku: {
    name: skuName
    tier: skuTier
    capacity: skuCapacity
  }
  properties: {
    reserved: true
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    IngestionMode: 'ApplicationInsights'
  }
}

resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: appName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: runtime
      appCommandLine: 'python -m uvicorn main:app --host 0.0.0.0 --port 8000'
      alwaysOn: true
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: '1'
        }
        {
          name: 'WEBSITES_PORT'
          value: '8000'
        }
        {
          name: 'PYTHON_VERSION'
          value: '3.13'
        }
        {
          name: 'OTEL_SERVICE_NAME'
          value: appName
        }
        {
          name: 'OTEL_SERVICE_NAMESPACE'
          value: 'webapp'
        }
        {
          name: 'OTEL_PYTHON_RESOURCE_DETECTORS'
          value: 'azure_app_service,env,process'
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: 'disabled'
        }
        {
          name: 'OTEL_EXPORTER_AZUREMONITOR_LIVEMETRICS_ENABLED'
          value: 'true'
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

output webAppName string = webApp.name
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
