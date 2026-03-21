@description('The name of the Azure Function app.')
param functionAppName string = 'func-appt-${instanceNumber}-${uniqueString(resourceGroup().id)}'

@description('The instance number of the Azure Function app.')
param instanceNumber string = '002'

@description('The name of the table to create in the storage account.')
param appointmentTableName string = 'Appointments'

@description('Storage Account type')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param storageAccountType string = 'Standard_LRS'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Location for Application Insights')
param appInsightsLocation string = resourceGroup().location

@description('The language worker runtime to load in the function app.')
@allowed([
  'dotnet'
  'dotnet-isolated'
  'node'
  'python'
  'java'
])
param functionWorkerRuntime string = 'dotnet-isolated'

@description('Required for Linux app to represent runtime stack in the format of \'runtime|runtimeVersion\'. For example: \'python|3.9\'')
param linuxFxVersion string = 'dotnet-isolated|8.0'

//@description('The zip content url.')
//param packageUri string

var hostingPlanName = 'asp-appt-${instanceNumber}-${uniqueString(resourceGroup().id)}'
var applicationInsightsName = 'appi-appt-${instanceNumber}-${uniqueString(resourceGroup().id)}'
var storageAccountName = 'stappt${instanceNumber}${uniqueString(resourceGroup().id)}'
var containerRegistryName = 'crappt${instanceNumber}${uniqueString(resourceGroup().id)}'
var logAnalyticsName = 'log-appt-${instanceNumber}-${uniqueString(resourceGroup().id)}'

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

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  // allow storage account to be accessed from the function app
  properties: {
    networkAcls: {
      defaultAction: 'Allow'
      // allow access from the function app
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
    }
    allowSharedKeyAccess: true // should use managed identity instead
  }

  // add table services
  resource tableService 'tableServices@2023-05-01' = {
    name: 'default'
    resource table 'tables@2023-05-01' = {
      name: appointmentTableName
    }
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
  }
  properties: {
    reserved: true
  }
}

resource applicationInsight 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: appInsightsLocation
  tags: {
    'hidden-link:${resourceId('Microsoft.Web/sites', functionAppName)}': 'Resource'
  }
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
  kind: 'web'
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    reserved: true
    serverFarmId: hostingPlan.id
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsight.properties.InstrumentationKey
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
          value: applicationInsight.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsight.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsight.properties.ConnectionString
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
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: '0'
        }
        {
          name: 'StorageAccountAppointmentsTable'
          value: appointmentTableName
        }
        {
          name: 'StorageConnectionString'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_USE_PLACEHOLDER_DOTNETISOLATED'
          value: '1'
        }
      ]
    }
  }

  resource scm 'basicPublishingCredentialsPolicies@2024-04-01' = {
    name: 'scm'
    properties: {
      //enable basic auth for the app
      allow: true
    }
  }
}

output functionAppName string = functionApp.name
output storageAccountName string = storageAccount.name
output containerRegistryName string = containerRegistry.name
output hostingPlanName string = hostingPlan.name
output applicationInsightsName string = applicationInsight.name
