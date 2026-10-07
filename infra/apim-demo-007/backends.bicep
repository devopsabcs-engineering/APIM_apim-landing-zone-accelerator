// Per-environment backend hosting for the APIM 007 demo. Hosting only: images come from the
// provisioning workflow (existing app's current linuxFxVersion, or the bootstrap image for a new app).

@description('Environment name')
@allowed([
  'dev'
  'prod'
])
param environmentName string

@description('Azure region where the resources will be deployed')
param location string = resourceGroup().location

@description('Object ID of the release service principal; granted Website Contributor on the resource group')
@minLength(36)
@maxLength(36)
param releasePrincipalId string

@description('linuxFxVersion for the weather app, for example DOCKER|<registry>/<repo>@sha256:<digest>')
@minLength(8)
param weatherLinuxFxVersion string

@description('linuxFxVersion for the software-version app, for example DOCKER|<registry>/<repo>@sha256:<digest>')
@minLength(8)
param softwareVersionLinuxFxVersion string

var suffix = uniqueString(resourceGroup().id)
var planName = 'asp-apim007-${environmentName}-${suffix}'
var websiteContributorRoleId = 'de139f84-1756-47ae-9be6-808fbbe84772'

var tags = {
  apimDemo: '007'
  environment: environmentName
  owner: 'apim-demo-007'
}

var apps = [
  {
    key: 'weather'
    linuxFxVersion: weatherLinuxFxVersion
  }
  {
    key: 'software-version'
    linuxFxVersion: softwareVersionLinuxFxVersion
  }
]

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: tags
  kind: 'linux'
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  properties: {
    reserved: true
  }
}

resource sites 'Microsoft.Web/sites@2023-12-01' = [
  for app in apps: {
    name: 'app-apim007-${environmentName}-${app.key}-${suffix}'
    location: location
    tags: tags
    kind: 'app,linux,container'
    identity: {
      type: 'SystemAssigned'
    }
    properties: {
      serverFarmId: plan.id
      httpsOnly: true
      siteConfig: {
        linuxFxVersion: app.linuxFxVersion
        acrUseManagedIdentityCreds: true
        alwaysOn: true
        minTlsVersion: '1.2'
        ftpsState: 'Disabled'
        appSettings: [
          {
            name: 'WEBSITES_PORT'
            value: '8080'
          }
          {
            name: 'ASPNETCORE_FORWARDEDHEADERS_ENABLED'
            value: 'true'
          }
          {
            name: 'DOCKER_ENABLE_CI'
            value: 'false'
          }
        ]
      }
    }
  }
]

resource ftpPolicies 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = [
  for (app, i) in apps: {
    parent: sites[i]
    name: 'ftp'
    properties: {
      allow: false
    }
  }
]

resource scmPolicies 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = [
  for (app, i) in apps: {
    parent: sites[i]
    name: 'scm'
    properties: {
      allow: false
    }
  }
]

resource releaseWebsiteContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, releasePrincipalId, websiteContributorRoleId)
  properties: {
    principalId: releasePrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', websiteContributorRoleId)
    principalType: 'ServicePrincipal'
  }
}

output weatherAppName string = sites[0].name
output weatherAppId string = sites[0].id
output weatherDefaultHostName string = sites[0].properties.defaultHostName
output weatherHttpsBaseUrl string = 'https://${sites[0].properties.defaultHostName}'
output weatherPrincipalId string = sites[0].identity.principalId

output softwareVersionAppName string = sites[1].name
output softwareVersionAppId string = sites[1].id
output softwareVersionDefaultHostName string = sites[1].properties.defaultHostName
output softwareVersionHttpsBaseUrl string = 'https://${sites[1].properties.defaultHostName}'
output softwareVersionPrincipalId string = sites[1].identity.principalId
