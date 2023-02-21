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

param apimUserIdentityId string

@secure()
param apiCertificatePassword string
param apiFqdn string
// 'https://kv-apimlz03-dev-canadace${environment().suffixes.keyvaultDns}/secrets/management-mngenv019702-onmicrosoft-com'
param apiCertificateKeyVaultId string
@secure()
param portalCertificatePassword string
param portalFqdn string
param portalCertificateKeyVaultId string
@secure()
param managementCertificatePassword string
param managementFqdn string
param managementCertificateKeyVaultId string

param apimUserIdentityClientId string

/*
 * Resources
*/

resource apimName_resource 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: apimName
  location: location
  sku: {
    capacity: capacity
    name: skuName
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${apimUserIdentityId}': {}
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
        hostName: apiFqdn
        negotiateClientCertificate: false
        // certificate: {
        //   expiry: '2023-12-01T01:03:32+00:00'
        //   thumbprint: '01F83F79F55BEBC5BEA2943253CAB3335BC3A946'
        //   subject: 'CN=api.MngEnv019702.onmicrosoft.com, O=Contoso, L=Montreal, S=Quebec, C=CA'
        // }
        defaultSslBinding: true
        //certificateSource: 'Custom'
        certificatePassword: apiCertificatePassword
        //encodedCertificate: ''
        identityClientId: apimUserIdentityClientId
        keyVaultId: apiCertificateKeyVaultId
      }
      {
        type: 'DeveloperPortal'
        hostName: portalFqdn
        negotiateClientCertificate: false
        // certificate: {
        //   expiry: '2023-12-01T01:03:34+00:00'
        //   thumbprint: 'A0E92738CF5A9F0ED6DA44CFF57F50DDA7532ADA'
        //   subject: 'CN=portal.MngEnv019702.onmicrosoft.com, O=Contoso, L=Montreal, S=Quebec, C=CA'
        // }
        defaultSslBinding: false
        //certificateSource: 'Custom'
        certificatePassword: portalCertificatePassword
        //encodedCertificate: ''
        identityClientId: apimUserIdentityClientId
        keyVaultId: portalCertificateKeyVaultId
      }
      {
        type: 'Management'
        hostName: managementFqdn
        negotiateClientCertificate: false
        // certificate: {
        //   expiry: '2023-12-01T01:03:35+00:00'
        //   thumbprint: '36425F6F48EBE02A0D7AE26A8CCCC008A4EFE744'
        //   subject: 'CN=management.MngEnv019702.onmicrosoft.com, O=Contoso, L=Montreal, S=Quebec, C=CA'
        // }
        defaultSslBinding: false
        //certificateSource: 'Custom'
        certificatePassword: managementCertificatePassword
        //encodedCertificate: ''
        identityClientId: apimUserIdentityClientId
        keyVaultId: managementCertificateKeyVaultId
      }
    ]
  }
}

resource apimName_appInsightsLogger_resource 'Microsoft.ApiManagement/service/loggers@2021-08-01' = {
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

resource apimName_applicationinsights 'Microsoft.ApiManagement/service/diagnostics@2021-08-01' = {
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
