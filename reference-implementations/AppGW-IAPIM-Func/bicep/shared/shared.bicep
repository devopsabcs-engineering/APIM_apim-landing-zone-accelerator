targetScope = 'resourceGroup'
// Parameters
@description('Azure location to which the resources are to be deployed')
param location string

@description('The full id string identifying the target subnet for the jumpbox VM')
param jumpboxSubnetId string

@description('The full id string identifying the target subnet for the CI/CD Agent VM')
param CICDAgentSubnetId string

@description('The user name to be used as the Administrator for all VMs created by this deployment')
param vmUsername string

@description('The password for the Administrator user for all VMs created by this deployment')
@secure()
param vmPassword string

@description('The CI/CD platform to be used, and for which an agent will be configured for the ASE deployment. Specify \'none\' if no agent needed')
@allowed([
  'github'
  'azuredevops'
  'none'
])
param CICDAgentType string

@description('The Azure DevOps or GitHub account name to be used when configuring the CI/CD agent, in the format https://dev.azure.com/ORGNAME OR github.com/ORGUSERNAME OR none')
param accountName string

@description('The Azure DevOps or GitHub personal access token (PAT) used to setup the CI/CD agent')
@secure()
param personalAccessToken string

@description('The name of the shared resource group')
param resourceGroupName string

@description('Standardized suffix text to be added to resource names')
param resourceSuffix string

@description('The environment for which the deployment is being executed')
@allowed([
  'dev'
  'uat'
  'prd'
  'dsr'
])
param environment string

@secure()
param certPassword string

@description('The FQDN of the Api.Must match the TLS Certificate.')
param apiFQDN string
@description('Set to selfsigned if self signed certificates should be used for the Api. Set to custom and copy the pfx file to deployment/bicep/gateway/certs/api.pfx if custom certificates are to be used')
param apiCertType string
@secure()
param apiCertPassword string

@description('The FQDN of the Portal.Must match the TLS Certificate.')
param portalFQDN string
@description('Set to selfsigned if self signed certificates should be used for the Portal. Set to custom and copy the pfx file to deployment/bicep/gateway/certs/portal.pfx if custom certificates are to be used')
param portalCertType string
@secure()
param portalCertPassword string

@description('The FQDN of the Management.Must match the TLS Certificate.')
param managementFQDN string
@description('Set to selfsigned if self signed certificates should be used for the Management. Set to custom and copy the pfx file to deployment/bicep/gateway/certs/management.pfx if custom certificates are to be used')
param managementCertType string
@secure()
param managementCertPassword string

@description('The FQDN of the Application Gateawy.Must match the TLS Certificate.')
param appGatewayFQDN string = 'api.example.com'
@description('Set to selfsigned if self signed certificates should be used for the Application Gateway. Set to custom and copy the pfx file to deployment/bicep/gateway/certs/appgw.pfx if custom certificates are to be used')
param appGatewayCertType string

@description('The common user identity name to be created.')
param commonUserIdentityName string

@description('Valid SKU indicator for the VM')
param vmSize string = 'Standard_D4_v3'

// Variables - ensure key vault name does not end with '-'
var tempKeyVaultName = take('kv-${resourceSuffix}', 24) // Must be between 3-24 alphanumeric characters 
var keyVaultName = endsWith(tempKeyVaultName, '-') ? substring(tempKeyVaultName, 0, length(tempKeyVaultName) - 1) : tempKeyVaultName

// Resources
module appInsights './azmon.bicep' = {
  name: 'azmon'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    resourceSuffix: resourceSuffix
  }
}

module vm_devopswinvm './createvmwindows.bicep' = if (toLower(CICDAgentType) != 'none') {
  name: 'devopsvm'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    subnetId: CICDAgentSubnetId
    username: vmUsername
    password: vmPassword
    vmName: '${CICDAgentType}-${environment}'
    accountName: accountName
    personalAccessToken: personalAccessToken
    CICDAgentType: CICDAgentType
    deployAgent: true

    vmSize: vmSize
  }
}

module vm_jumpboxwinvm './createvmwindows.bicep' = {
  name: 'vm-jumpbox'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    subnetId: jumpboxSubnetId
    username: vmUsername
    password: vmPassword
    CICDAgentType: CICDAgentType
    vmName: 'jumpbox-${environment}'
    vmSize: vmSize
  }
}

//certificates and user identity for apim and appgw
resource commonUserIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: commonUserIdentityName
  location: location
}

module certificate './modules/certificate.bicep' = {
  name: 'certificate'
  scope: resourceGroup(resourceGroupName)
  params: {
    managedIdentity: commonUserIdentity
    keyVaultName: keyVaultName
    location: location
    appGatewayFQDN: appGatewayFQDN
    appGatewayCertType: appGatewayCertType
    certPassword: certPassword
  }
}
module certificateApi './modules/certificateApi.bicep' = {
  name: 'certificateApi'
  scope: resourceGroup(resourceGroupName)
  params: {
    managedIdentity: commonUserIdentity
    keyVaultName: keyVaultName
    location: location
    appGatewayFQDN: apiFQDN
    appGatewayCertType: apiCertType
    certPassword: apiCertPassword
  }
}
module certificatePortal './modules/certificatePortal.bicep' = {
  name: 'certificatePortal'
  scope: resourceGroup(resourceGroupName)
  params: {
    managedIdentity: commonUserIdentity
    keyVaultName: keyVaultName
    location: location
    appGatewayFQDN: portalFQDN
    appGatewayCertType: portalCertType
    certPassword: portalCertPassword
  }
}
module certificateManagement './modules/certificateManagement.bicep' = {
  name: 'certificateManagement'
  scope: resourceGroup(resourceGroupName)
  params: {
    managedIdentity: commonUserIdentity
    keyVaultName: keyVaultName
    location: location
    appGatewayFQDN: managementFQDN
    appGatewayCertType: managementCertType
    certPassword: managementCertPassword
  }
}

resource key_vault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: [
      // {
      //   tenantId: 'string'
      //   objectId: 'string'
      //   applicationId: 'string'
      //   permissions: {
      //     keys: [
      //       'string'
      //     ]
      //     secrets: [
      //       'string'
      //     ]
      //     certificates: [
      //       'string'
      //     ]
      //     storage: [
      //       'string'
      //     ]
      //   }
      // }
    ]
  }
}

// Outputs
output appInsightsConnectionString string = appInsights.outputs.appInsightsConnectionString
output CICDAgentVmName string = vm_devopswinvm.name
output jumpBoxvmName string = vm_jumpboxwinvm.name
output appInsightsName string = appInsights.outputs.appInsightsName
output appInsightsId string = appInsights.outputs.appInsightsId
output appInsightsInstrumentationKey string = appInsights.outputs.appInsightsInstrumentationKey
output keyVaultName string = key_vault.name
output commonUserIdentityId string = commonUserIdentity.id
output commonUserIdentityClientId string = commonUserIdentity.properties.clientId
output commonUserIdentityPrincipalId string = commonUserIdentity.properties.principalId
output certificateApiSecretUri string = certificateApi.outputs.secretUri
output certificateManagementSecretUri string = certificateManagement.outputs.secretUri
output certificatePortalSecretUri string = certificatePortal.outputs.secretUri
