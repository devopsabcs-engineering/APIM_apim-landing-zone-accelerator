targetScope = 'subscription'

// Parameters
@description('A short name for the workload being deployed alphanumberic only')
@maxLength(8)
param workloadName string

@description('The environment for which the deployment is being executed')
@allowed([
  'dev'
  'uat'
  'prod'
  'dr'
])
param environment string

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

@description('The FQDN for the Application Gateway. Example - api.contoso.com.')
param appGatewayFqdn string

@description('The password for the TLS certificate for the Application Gateway.  The pfx file needs to be copied to deployment/bicep/gateway/certs/appgw.pfx')
@secure()
param certificatePassword string

@description('Set to selfsigned if self signed certificates should be used for the Application Gateway. Set to custom and copy the pfx file to deployment/bicep/gateway/certs/appgw.pfx if custom certificates are to be used')
param appGatewayCertType string

param location string = deployment().location

@description('The FQDN for the Api. Example - api.contoso.com.')
param apiFQDN string
@description('The password for the TLS certificate for the Api.  The pfx file needs to be copied to deployment/bicep/gateway/certs/api.pfx')
@secure()
param apiCertificatePassword string
@description('Set to selfsigned if self signed certificates should be used for the Api. Set to custom and copy the pfx file to deployment/bicep/gateway/certs/api.pfx if custom certificates are to be used')
param apiCertType string

@description('The FQDN for the Portal. Example - portal.contoso.com.')
param portalFQDN string
@description('The password for the TLS certificate for the Portal.  The pfx file needs to be copied to deployment/bicep/gateway/certs/portal.pfx')
@secure()
param portalCertificatePassword string
@description('Set to selfsigned if self signed certificates should be used for the Portal. Set to custom and copy the pfx file to deployment/bicep/gateway/certs/portal.pfx if custom certificates are to be used')
param portalCertType string

@description('The FQDN for the Management. Example - management.contoso.com.')
param managementFQDN string
@description('The password for the TLS certificate for the Management.  The pfx file needs to be copied to deployment/bicep/gateway/certs/management.pfx')
@secure()
param managementCertificatePassword string
@description('Set to selfsigned if self signed certificates should be used for the Management. Set to custom and copy the pfx file to deployment/bicep/gateway/certs/management.pfx if custom certificates are to be used')
param managementCertType string

// Variables
var resourceSuffix = '${workloadName}-${environment}-${location}-003'
var networkingResourceGroupName = 'rg-networking-${resourceSuffix}'
var sharedResourceGroupName = 'rg-shared-${resourceSuffix}'

var backendResourceGroupName = 'rg-backend-${resourceSuffix}'

var apimResourceGroupName = 'rg-apim-${resourceSuffix}'

// Resource Names
var apimName = 'apim-${resourceSuffix}'
var appGatewayName = 'appgw-${resourceSuffix}'

resource networkingRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: networkingResourceGroupName
  location: location
}

resource backendRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: backendResourceGroupName
  location: location
}

resource sharedRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: sharedResourceGroupName
  location: location
}

resource apimRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: apimResourceGroupName
  location: location
}

module networking './networking/networking.bicep' = {
  name: 'networkingresources'
  scope: resourceGroup(networkingRG.name)
  params: {
    workloadName: workloadName
    deploymentEnvironment: environment
    location: location
  }
}

module backend './backend/backend.bicep' = {
  name: 'backendresources'
  scope: resourceGroup(backendRG.name)
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    vnetName: networking.outputs.apimCSVNetName
    vnetRG: networkingRG.name
    backendSubnetId: networking.outputs.backEndSubnetid
    privateEndpointSubnetid: networking.outputs.privateEndpointSubnetid
  }
}

var jumpboxSubnetId = networking.outputs.jumpBoxSubnetid
var CICDAgentSubnetId = networking.outputs.CICDAgentSubnetId

module shared './shared/shared.bicep' = {
  dependsOn: [
    networking
  ]
  name: 'sharedresources'
  scope: resourceGroup(sharedRG.name)
  params: {
    accountName: accountName
    CICDAgentSubnetId: CICDAgentSubnetId
    CICDAgentType: CICDAgentType
    environment: environment
    jumpboxSubnetId: jumpboxSubnetId
    location: location
    personalAccessToken: personalAccessToken
    resourceGroupName: sharedRG.name
    resourceSuffix: resourceSuffix
    vmPassword: vmPassword
    vmUsername: vmUsername
  }
}

module apimModule 'apim/apim.bicep' = {
  name: 'apimDeploy'
  scope: resourceGroup(apimRG.name)
  params: {
    apimName: apimName
    apimSubnetId: networking.outputs.apimSubnetid
    location: location
    appInsightsName: shared.outputs.appInsightsName
    appInsightsId: shared.outputs.appInsightsId
    appInsightsInstrumentationKey: shared.outputs.appInsightsInstrumentationKey
    publisherEmail: 'admin@MngEnv019702.onmicrosoft.com'
    publisherName: 'Contoso MngEnv019702'
  }
}

//Creation of private DNS zones
module dnsZoneModule 'shared/dnszone.bicep' = {
  name: 'apimDnsZoneDeploy'
  scope: resourceGroup(sharedRG.name)
  dependsOn: [
    apimModule
  ]
  params: {
    vnetName: networking.outputs.apimCSVNetName
    vnetRG: networkingRG.name
    apimName: apimName
    apimRG: apimRG.name
  }
}

module appgwModule 'gateway/appgw.bicep' = {
  name: 'appgwDeploy'
  scope: resourceGroup(apimRG.name)
  dependsOn: [
    apimModule
    dnsZoneModule
  ]
  params: {
    appGatewayName: appGatewayName
    appGatewayFQDN: appGatewayFqdn
    location: location
    appGatewaySubnetId: networking.outputs.appGatewaySubnetid
    primaryBackendEndFQDN: '${apimName}.azure-api.net'
    keyVaultName: shared.outputs.keyVaultName
    keyVaultResourceGroupName: sharedRG.name
    appGatewayCertType: appGatewayCertType
    certPassword: certificatePassword
    apiCertPassword: apiCertificatePassword
    apiCertType: apiCertType
    apiFQDN: apiFQDN
    portalCertPassword: portalCertificatePassword
    portalCertType: portalCertType
    portalFQDN: portalFQDN
    managementCertPassword: managementCertificatePassword
    managementCertType: managementCertType
    managementFQDN: managementFQDN
  }
}
