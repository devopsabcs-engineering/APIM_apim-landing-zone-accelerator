@description('The name of the function app that you wish to create.')
param appName string = 'func-${uniqueString(resourceGroup().id)}'

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
param appInsightsLocation string

@description('The language worker runtime to load in the function app.')
@allowed([
  'node'
  'dotnet'
  'java'
])
param runtime string = 'dotnet'

param publicApimVirtualIp string

@secure()
param backendClientSecret string
param backendClientId string
//param b2cTenantName string //= 'testekb2c008'
//param userFlowId string //= 'frontendapp_dev_signupandsignin'
param openIdIssuer string //= 'https://testekb2c008.b2clogin.com/testekb2c008.onmicrosoft.com/v2.0/'
//openIdIssuer: 'https://login.microsoftonline.com/${tenantId}/v2.0'
//openIdIssuer: 'https://${b2cTenantName}.b2clogin.com/${b2cTenantName}.onmicrosoft.com/v2.0/.well-known/openid-configuration?p=B2C_1_${userFlowId}'

var functionAppName = appName
var hostingPlanName = 'plan-${uniqueString(resourceGroup().id)}'
var applicationInsightsName = 'appi-${uniqueString(resourceGroup().id)}'
var storageAccountName = 'stf${uniqueString(resourceGroup().id)}'
var functionWorkerRuntime = runtime

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'Storage'
}

resource hostingPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}

resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  // identity: {
  //   type: 'SystemAssigned'
  // }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
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
        // {
        //   name: 'WEBSITE_NODE_DEFAULT_VERSION'
        //   value: '~10'
        // }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          //value: 'InstrumentationKey=${applicationInsights.properties.InstrumentationKey};IngestionEndpoint=https://${location}-1.in.applicationinsights.azure.com/;LiveEndpoint=https://${location}.livediagnostics.monitor.azure.com/'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET' //the official name when generating using express
          //value: '@Microsoft.KeyVault(SecretUri=${keyVault::adClientSecretKvSecret.properties.secretUriWithVersion})'
          value: backendClientSecret
        }
      ]
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
      netFrameworkVersion: '6.0'

      ipSecurityRestrictions: [
        {
          ipAddress: '${publicApimVirtualIp}/32'
          action: 'Allow'
          tag: 'Default'
          priority: 300
          name: 'Apim Public Virtual IP'
          description: 'public apim virtual ip'
        }
        // {
        //   ipAddress: '10.2.7.5/32'
        //   action: 'Allow'
        //   tag: 'Default'
        //   priority: 310
        //   name: 'Dev Apim Private Virtual Apim'
        // }
        // {
        //   ipAddress: '20.175.184.156/32'
        //   action: 'Allow'
        //   tag: 'Default'
        //   priority: 320
        //   name: 'Prod Apim Public Virtual Apim'
        //   description: 'public: 20.175.184.156'
        // }
        // {
        //   ipAddress: '174.92.215.24/32'
        //   action: 'Allow'
        //   tag: 'Default'
        //   priority: 330
        //   name: 'Developer Public IP (temporary)'
        //   description: 'Emmanuel Public IP - for azure portal access of azure fn'
        // }
        {
          ipAddress: 'Any'
          action: 'Deny'
          priority: 2147483647
          name: 'Deny all'
          description: 'Deny all access'
        }
      ]
    }
    httpsOnly: true
  }
}

resource authSettings 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: functionApp
  name: 'authsettingsV2'
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'Return401' //'RedirectToLoginPage'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          openIdIssuer: openIdIssuer
          clientId: backendClientId
          clientSecretSettingName: 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'
        }
        // validation: {
        //   allowedAudiences: [
        //     'api://${backendClientId}'
        //   ]
        // }
        isAutoProvisioned: false
      }
    }
    login: {
      tokenStore: {
        enabled: true
      }
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: appInsightsLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}

//also want the storage static website
module modStorageStaticWebsite 'modules/storage-static-website.bicep' = {
  name: 'staticwebsite'
  //scope: resourceGroup()
  params: {
    location: location
  }
}

output staticWebsiteUrl string = modStorageStaticWebsite.outputs.staticWebsiteUrl
output functionName string = functionApp.name
