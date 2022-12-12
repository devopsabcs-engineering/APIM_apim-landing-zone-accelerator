targetScope = 'resourceGroup'

/*
 * Input parameters
*/

@description('The name of the API Management resource to be created.')
param apimName string

@description('The subnet resource id to use for APIM.')
@minLength(1)
param apimSubnetId string

@description('The email address of the publisher of the APIM resource.')
@minLength(1)
param publisherEmail string = 'apim@contoso.com'

@description('Company name of the publisher of the APIM resource.')
@minLength(1)
param publisherName string = 'Contoso'

@description('The pricing tier of the APIM resource.')
param skuName string = 'Developer'

@description('The instance size of the APIM resource.')
param capacity int = 1

@description('Location for Azure resources.')
param location string = resourceGroup().location

param appInsightsName string
param appInsightsId string
param appInsightsInstrumentationKey string

/*
 * Resources
*/

resource apimName_resource 'Microsoft.ApiManagement/service@2020-12-01' = {
  name: apimName
  location: location
  sku: {
    capacity: capacity
    name: skuName
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      // '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/identity-appgw-ApimLZ03-dev-canadacentral-003': {
      //   clientId: '1216d0de-27c4-49b9-a97d-4f0c16590cee'
      //   principalId: '6b5cf262-62d7-45a8-b008-e403f29d4a27'
      // }
      '/subscriptions/c04c476e-1725-4c9d-8a98-31f91163a0eb/resourcegroups/rg-apim-ApimLZ03-dev-canadacentral-003/providers/Microsoft.ManagedIdentity/userAssignedIdentities/identity-appgw-ApimLZ03-dev-canadacentral-003': {

      }
    }
  }
  properties: {
    virtualNetworkType: 'Internal'
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkConfiguration: {
      subnetResourceId: apimSubnetId
    }
    hostnameConfigurations: [
      {
        type: 'Proxy'
        hostName: 'api.MngEnv019702.onmicrosoft.com'
        negotiateClientCertificate: false
        // certificate: {
        //   expiry: '2023-12-01T01:03:32+00:00'
        //   thumbprint: '01F83F79F55BEBC5BEA2943253CAB3335BC3A946'
        //   subject: 'CN=api.MngEnv019702.onmicrosoft.com, O=Contoso, L=Montreal, S=Quebec, C=CA'
        // }
        defaultSslBinding: true
        //certificateSource: 'Custom'
        certificatePassword: 'Test12345!'
        //encodedCertificate: ''
        identityClientId: '1216d0de-27c4-49b9-a97d-4f0c16590cee'
        keyVaultId: 'https://kv-apimlz03-dev-canadace.${environment().suffixes.keyvaultDns}/secrets/api-mngenv019702-onmicrosoft-com'
      }
      {
        type: 'DeveloperPortal'
        hostName: 'portal.MngEnv019702.onmicrosoft.com'
        negotiateClientCertificate: false
        // certificate: {
        //   expiry: '2023-12-01T01:03:34+00:00'
        //   thumbprint: 'A0E92738CF5A9F0ED6DA44CFF57F50DDA7532ADA'
        //   subject: 'CN=portal.MngEnv019702.onmicrosoft.com, O=Contoso, L=Montreal, S=Quebec, C=CA'
        // }
        defaultSslBinding: false
        //certificateSource: 'Custom'
        certificatePassword: 'Test12345!'
        //encodedCertificate: ''
        identityClientId: '1216d0de-27c4-49b9-a97d-4f0c16590cee'
        keyVaultId: 'https://kv-apimlz03-dev-canadace.${environment().suffixes.keyvaultDns}/secrets/portal-mngenv019702-onmicrosoft-com'
      }
      {
        type: 'Management'
        hostName: 'management.MngEnv019702.onmicrosoft.com'
        negotiateClientCertificate: false
        // certificate: {
        //   expiry: '2023-12-01T01:03:35+00:00'
        //   thumbprint: '36425F6F48EBE02A0D7AE26A8CCCC008A4EFE744'
        //   subject: 'CN=management.MngEnv019702.onmicrosoft.com, O=Contoso, L=Montreal, S=Quebec, C=CA'
        // }
        defaultSslBinding: false
        //certificateSource: 'Custom'
        certificatePassword: 'Test12345!'
        //encodedCertificate: ''
        identityClientId: '1216d0de-27c4-49b9-a97d-4f0c16590cee'
        keyVaultId: 'https://kv-apimlz03-dev-canadace.${environment().suffixes.keyvaultDns}/secrets/management-mngenv019702-onmicrosoft-com'
      }
    ]
  }
}

resource apimName_appInsightsLogger_resource 'Microsoft.ApiManagement/service/loggers@2019-01-01' = {
  parent: apimName_resource
  name: appInsightsName
  properties: {
    loggerType: 'applicationInsights'
    resourceId: appInsightsId
    credentials: {
      instrumentationKey: appInsightsInstrumentationKey
    }
  }
}

resource apimName_applicationinsights 'Microsoft.ApiManagement/service/diagnostics@2019-01-01' = {
  parent: apimName_resource
  name: 'applicationinsights'
  properties: {
    loggerId: apimName_appInsightsLogger_resource.id
    alwaysLog: 'allErrors'
    sampling: {
      percentage: 100
      samplingType: 'fixed'
    }
  }
}
