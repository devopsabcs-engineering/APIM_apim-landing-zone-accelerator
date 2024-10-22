@description('That name is the name of our application. It has to be unique.Type a name followed by your resource group name. (<name>-<resourceGroupName>)')
param webAppName string = 'app-flask-${uniqueString(resourceGroup().id)}'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of key vault. It has to be unique.Type a name followed by your resource group name. (<name>-<resourceGroupName>)')
param keyVaultName string = 'kv-${uniqueString(resourceGroup().id)}'

@description('Python version to use for the app. Valid values are: 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12')
@allowed([
  '3.6'
  '3.7'
  '3.8'
  '3.9'
  '3.10'
  '3.11'
  '3.12'
  //'3.13'
])
param pythonVersion string = '3.9'

var alwaysOn = false
var sku = 'Free'
var skuCode = 'F1'
var workerSizeId = 0
var numberOfWorkers = 1
var linuxFxVersion = 'PYTHON|${pythonVersion}'
var hostingPlanName = 'asp-${resourceGroup().name}'

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  properties: {
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      alwaysOn: alwaysOn
      appSettings: [
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'WEBSITE_HTTPLOGGING_RETENTION_DAYS'
          value: '3'
        }
        {
          name: 'CLIENT_ID'
          value: '239749a9-dccf-4e6b-b13c-ed390b53cc9b'
        }
        {
          name: 'CLIENT_SECRET'
          // use the secret value from the key vault
          value: '@Microsoft.KeyVault(SecretUri=${secret.properties.secretUri})'
        }
        {
          name: 'AUTHORITY'
          value: '${environment().authentication.loginEndpoint}${tenant().tenantId}'
        }
      ]
    }
    serverFarmId: hostingPlan.id
    clientAffinityEnabled: false
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

resource hostingPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: hostingPlanName
  location: location
  kind: 'linux'
  properties: {
    targetWorkerCount: numberOfWorkers
    targetWorkerSizeId: workerSizeId
    reserved: true
  }
  sku: {
    tier: sku
    name: skuCode
  }
}

// add key vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    tenantId: tenant().tenantId
    accessPolicies: []
    enableRbacAuthorization: true
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// assign identity of web app to key vault through RBAC
@description('Specifies the role the user will get with the secret in the vault. Valid values are: Key Vault Administrator, Key Vault Certificates Officer, Key Vault Crypto Officer, Key Vault Crypto Service Encryption User, Key Vault Crypto User, Key Vault Reader, Key Vault Secrets Officer, Key Vault Secrets User.')
@allowed([
  'Key Vault Administrator'
  'Key Vault Certificates Officer'
  'Key Vault Crypto Officer'
  'Key Vault Crypto Service Encryption User'
  'Key Vault Crypto User'
  'Key Vault Reader'
  'Key Vault Secrets Officer'
  'Key Vault Secrets User'
])
param roleName string = 'Key Vault Secrets User'

var roleIdMapping = {
  'Key Vault Administrator': '00482a5a-887f-4fb3-b363-3b7fe8e74483'
  'Key Vault Certificates Officer': 'a4417e6f-fecd-4de8-b567-7b0420556985'
  'Key Vault Crypto Officer': '14b46e9e-c2b7-41b4-b07b-48a6ebf60603'
  'Key Vault Crypto Service Encryption User': 'e147488a-f6f5-4113-8e2d-b22465e65bf6'
  'Key Vault Crypto User': '12338af0-0e69-4776-bea7-57ae8d297424'
  'Key Vault Reader': '21090545-7ca7-4776-b22c-e363652d74d2'
  'Key Vault Secrets Officer': 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
  'Key Vault Secrets User': '4633458b-17de-408a-b874-0445c86b69e6'
}

@description('Specifies the name of the secret that you want to create.')
param secretName string = 'ClientSecret'

@description('Specifies the value of the secret that you want to create.')
@secure()
param secretValue string

resource secret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: secretName
  properties: {
    value: secretValue
  }
}

resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(roleIdMapping[roleName], keyVault.id)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIdMapping[roleName])
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output webAppId string = webApp.id
output hostingPlanId string = hostingPlan.id
output webAppName string = webApp.name
