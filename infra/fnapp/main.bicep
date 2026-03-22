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

@description('Container image tag for the Function App. Set during deployment.')
param containerImageTag string = 'latest'

var hostingPlanName = 'asp-appt-${instanceNumber}-${uniqueString(resourceGroup().id)}'
var applicationInsightsName = 'appi-appt-${instanceNumber}-${uniqueString(resourceGroup().id)}'
var storageAccountName = 'stappt${instanceNumber}${uniqueString(resourceGroup().id)}'
var containerRegistryName = 'crappt${instanceNumber}${uniqueString(resourceGroup().id)}'
var logAnalyticsName = 'log-appt-${instanceNumber}-${uniqueString(resourceGroup().id)}'
var vnetName = 'vnet-appt-${instanceNumber}-${uniqueString(resourceGroup().id)}'
var funcSubnetName = 'snet-func'
var peSubnetName = 'snet-pe'

// ─── Networking ─────────────────────────────────────────────────────────────────

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: funcSubnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: peSubnetName
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
    ]
  }
}

// ─── Private DNS Zones ──────────────────────────────────────────────────────────

var storageDnsZones = [
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.queue.${environment().suffixes.storage}'
  'privatelink.table.${environment().suffixes.storage}'
  'privatelink.file.${environment().suffixes.storage}'
]

resource privateDnsZones 'Microsoft.Network/privateDnsZones@2024-06-01' = [
  for zone in storageDnsZones: {
    name: zone
    location: 'global'
  }
]

resource privateDnsZoneLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [
  for (zone, i) in storageDnsZones: {
    parent: privateDnsZones[i]
    name: '${vnetName}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
]

// ─── Logging ────────────────────────────────────────────────────────────────────

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      legacy: 0
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

// ─── Container Registry ─────────────────────────────────────────────────────────

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

// ─── Managed Identity ───────────────────────────────────────────────────────────

@description('User-assigned managed identity for the Function App to access storage and ACR without shared keys')
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-appt-${instanceNumber}-${uniqueString(resourceGroup().id)}'
  location: location
}

// ─── Storage Account (policy-compliant: no shared key, no public access) ────────

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  properties: {
    allowSharedKeyAccess: false
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Disabled'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }

  resource tableService 'tableServices@2023-05-01' = {
    name: 'default'
    resource table 'tables@2023-05-01' = {
      name: appointmentTableName
    }
  }
}

// ─── Private Endpoints for Storage ──────────────────────────────────────────────

var storageSubResources = ['blob', 'queue', 'table', 'file']

resource storagePrivateEndpoints 'Microsoft.Network/privateEndpoints@2024-01-01' = [
  for (subResource, i) in storageSubResources: {
    name: 'pe-${storageAccountName}-${subResource}'
    location: location
    properties: {
      subnet: {
        id: vnet.properties.subnets[1].id
      }
      privateLinkServiceConnections: [
        {
          name: 'psc-${subResource}'
          properties: {
            privateLinkServiceId: storageAccount.id
            groupIds: [subResource]
          }
        }
      ]
    }
  }
]

resource privateEndpointDnsGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = [
  for (subResource, i) in storageSubResources: {
    parent: storagePrivateEndpoints[i]
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config-${subResource}'
          properties: {
            privateDnsZoneId: privateDnsZones[i].id
          }
        }
      ]
    }
  }
]

// ─── App Service Plan ───────────────────────────────────────────────────────────

resource hostingPlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'S1'
    tier: 'Standard'
    size: 'S1'
    family: 'S'
    capacity: 1
  }
  properties: {
    reserved: true
  }
}

// ─── Application Insights ───────────────────────────────────────────────────────

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

// ─── Function App (container-based, VNet-integrated) ────────────────────────────

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux,container'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  dependsOn: [
    uamiStorageBlobDataOwnerRole
    uamiStorageAccountContributorRole
    uamiStorageQueueDataContributorRole
    uamiStorageTableDataContributorRole
    uamiStorageFileDataContributorRole
    uamiAcrPullRole
    storagePrivateEndpoints
    privateEndpointDnsGroups
  ]
  properties: {
    reserved: true
    serverFarmId: hostingPlan.id
    virtualNetworkSubnetId: vnet.properties.subnets[0].id
    keyVaultReferenceIdentity: managedIdentity.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerRegistry.properties.loginServer}/appointmentsapi:${containerImageTag}'
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: managedIdentity.properties.clientId
      vnetRouteAllEnabled: true
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsight.properties.ConnectionString
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
        // Identity-based AzureWebJobsStorage (no shared key)
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccountName
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'AzureWebJobsStorage__clientId'
          value: managedIdentity.properties.clientId
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
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'DOCKER_ENABLE_CI'
          value: 'false'
        }
        {
          name: 'StorageAccountAppointmentsTable'
          value: appointmentTableName
        }
        {
          name: 'StorageAccountName'
          value: storageAccountName
        }
        {
          name: 'MANAGED_IDENTITY_CLIENT_ID'
          value: managedIdentity.properties.clientId
        }
      ]
    }
  }
}

// ─── RBAC: UAMI → Storage ──────────────────────────────────────────────────────

// Storage Blob Data Owner (UAMI)
resource uamiStorageBlobDataOwnerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, managedIdentity.id, 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
  scope: storageAccount
  properties: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
  }
}

// Storage Account Contributor (UAMI)
resource uamiStorageAccountContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, managedIdentity.id, '17d1049b-9a84-46fb-8f53-869881c3d3ab')
  scope: storageAccount
  properties: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab')
  }
}

// Storage Queue Data Contributor (UAMI)
resource uamiStorageQueueDataContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, managedIdentity.id, '974c5e8b-45b9-4653-ba55-5f855dd0fb88')
  scope: storageAccount
  properties: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88')
  }
}

// Storage Table Data Contributor (UAMI)
resource uamiStorageTableDataContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, managedIdentity.id, '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3')
  scope: storageAccount
  properties: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3')
  }
}

// Storage File Data Privileged Contributor (UAMI)
resource uamiStorageFileDataContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, managedIdentity.id, '69566ab7-960f-475b-8e7c-b3118f30c6bd')
  scope: storageAccount
  properties: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '69566ab7-960f-475b-8e7c-b3118f30c6bd')
  }
}

// ─── RBAC: UAMI → ACR (AcrPull) ────────────────────────────────────────────────

resource uamiAcrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, managedIdentity.id, '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  scope: containerRegistry
  properties: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  }
}

// ─── RBAC: System Identity → Storage ────────────────────────────────────────────

// Storage Blob Data Owner (System)
resource sysStorageBlobDataOwnerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, functionApp.id, 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
  scope: storageAccount
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
  }
}

// Storage Account Contributor (System)
resource sysStorageAccountContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, functionApp.id, '17d1049b-9a84-46fb-8f53-869881c3d3ab')
  scope: storageAccount
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab')
  }
}

// Storage Queue Data Contributor (System)
resource sysStorageQueueDataContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, functionApp.id, '974c5e8b-45b9-4653-ba55-5f855dd0fb88')
  scope: storageAccount
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88')
  }
}

// Storage Table Data Contributor (System)
resource sysStorageTableDataContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, functionApp.id, '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3')
  scope: storageAccount
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3')
  }
}

// Storage File Data Privileged Contributor (System)
resource sysStorageFileDataContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, functionApp.id, '69566ab7-960f-475b-8e7c-b3118f30c6bd')
  scope: storageAccount
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '69566ab7-960f-475b-8e7c-b3118f30c6bd')
  }
}

// ─── Outputs ────────────────────────────────────────────────────────────────────

output functionAppName string = functionApp.name
output storageAccountName string = storageAccount.name
output containerRegistryName string = containerRegistry.name
output containerRegistryLoginServer string = containerRegistry.properties.loginServer
output hostingPlanName string = hostingPlan.name
output applicationInsightsName string = applicationInsight.name
output managedIdentityClientId string = managedIdentity.properties.clientId
