@description('The email address of the owner of the service')
@minLength(1)
param publisherEmail string = 'contoso@contoso.com'

@description('The name of the owner of the service')
@minLength(1)
param publisherName string = 'apimPublisher'

@description('The pricing tier of this API Management service')
@allowed([
  'Developer'
  'Premium'
])
param sku string = 'Developer'

@description('The instance size of this API Management service. This should be a multiple of the number of availability zones getting deployed.')
param skuCount int //= 1 //2

@description('Address prefix')
param virtualNetworkAddressPrefix string = '10.0.0.0/16'

@description('Subnet prefix')
param subnetPrefix string = '10.0.0.0/24'

@description('Service endpoints enabled on the API Management subnet')
param apimSubnetServiceEndpoints array = [
  {
    service: 'Microsoft.Storage'
  }
  {
    service: 'Microsoft.Sql'
  }
  {
    service: 'Microsoft.EventHub'
  }
]

@description('Azure region where the resources will be deployed')
param location string = resourceGroup().location

@description('Numbers for availability zones, for example, 1,2,3.')
param availabilityZones array = [
  '1'
  '2'
]

@description('SKU for the public IP address used to access the API Management service.')
@allowed([
  'Standard'
])
param publicIpSku string = 'Standard'

@description('Allocation method for the public IP address used to access the API Management service. Standard SKU public IP requires `Static` allocation.')
@allowed([
  'Static'
])
param publicIPAllocationMethod string = 'Static'

@description('Environment Name')
@allowed([
  'dev'
  'qa'
  'prod'
])
param environmentName string //= 'dev'

param instanceNumber string //= '01'

var deployGateway001 = true
var deployGateway002 = true

var applicationInsightsLoggerName = 'apimlogger'

var baseName = 'apim-${environmentName}-${instanceNumber}-${uniqueString(resourceGroup().id)}'

var apiManagementName = baseName
var subnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
var nsgName = 'nsg-${baseName}'
var applicationInsightsName = 'appi-${baseName}'
var logAnalyticsWorkspaceName = 'log-${baseName}'
var virtualNetworkName = 'vnet-${baseName}'
// trim the key vault name to 24 characters
var keyVaultName = substring('kv-${baseName}', 0, 24)
var subnetName = 'apimSubnet'
var publicIpName = 'pip-${baseName}'
var dnsPrefix = 'pocDNS'
var dnsLabelPrefix = toLower('${dnsPrefix}${publicIpName}')

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Client_communication_to_API_Management'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Secure_Client_communication_to_API_Management'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'Management_endpoint_for_Azure_portal_and_Powershell'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3443'
          sourceAddressPrefix: 'ApiManagement'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'Dependency_on_Redis_Cache'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '6381-6383'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'Dependency_to_sync_Rate_Limit_Inbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '4290'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 135
          direction: 'Inbound'
        }
      }
      {
        name: 'Dependency_on_Azure_SQL'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Sql'
          access: 'Allow'
          priority: 140
          direction: 'Outbound'
        }
      }
      {
        name: 'Dependency_for_Log_to_event_Hub_policy'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '5671'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'EventHub'
          access: 'Allow'
          priority: 150
          direction: 'Outbound'
        }
      }
      {
        name: 'Dependency_on_Redis_Cache_outbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '6381-6383'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 160
          direction: 'Outbound'
        }
      }
      {
        name: 'Depenedency_To_sync_RateLimit_Outbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '4290'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 165
          direction: 'Outbound'
        }
      }
      {
        name: 'Dependency_on_Azure_File_Share_for_GIT'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '445'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Storage'
          access: 'Allow'
          priority: 170
          direction: 'Outbound'
        }
      }
      {
        name: 'Azure_Infrastructure_Load_Balancer'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '6390'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 180
          direction: 'Inbound'
        }
      }
      {
        name: 'Publish_DiagnosticLogs_And_Metrics'
        properties: {
          description: 'API Management logs and metrics for consumption by admins and your IT team are all part of the management plane'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureMonitor'
          access: 'Allow'
          priority: 185
          direction: 'Outbound'
          destinationPortRanges: [
            '443'
            '12000'
            '1886'
          ]
        }
      }
      {
        name: 'Connect_To_SMTP_Relay_For_SendingEmails'
        properties: {
          description: 'APIM features the ability to generate email traffic as part of the data plane and the management plane'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 190
          direction: 'Outbound'
          destinationPortRanges: [
            '25'
            '587'
            '25028'
          ]
        }
      }
      //careful with 80 outbound -- doing this for Echo API and Super Hero http 80 API
      {
        name: 'CAREFUL_DEMO_AllowAnyCustom80Outbound'
        properties: {
          description: 'CAREFUL APIM access to Echo API and other http 80 graphql apis such as Super Hero API'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
          destinationPortRanges: [
            '80'
          ]
        }
      }
      {
        name: 'Authenticate_To_Azure_Active_Directory'
        properties: {
          description: 'Connect to Azure Active Directory for developer Portal authentication or for OAuth 2 flow during any proxy authentication'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureActiveDirectory'
          access: 'Allow'
          priority: 200
          direction: 'Outbound'
          destinationPortRanges: [
            '80'
            '443'
          ]
        }
      }
      {
        name: 'Dependency_on_Azure_Storage'
        properties: {
          description: 'API Management service dependency on Azure blob and Azure table storage'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Storage'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'Publish_Monitoring_Logs'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 300
          direction: 'Outbound'
        }
      }
      {
        name: 'Access_KeyVault'
        properties: {
          description: 'Allow API Management service control plane access to Azure Key Vault to refresh secrets'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureKeyVault'
          access: 'Allow'
          priority: 350
          direction: 'Outbound'
          destinationPortRanges: [
            '443'
          ]
        }
      }
      {
        name: 'Deny_All_Internet_Outbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Internet'
          access: 'Deny'
          priority: 999
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: publicIpName
  location: location
  sku: {
    name: publicIpSku
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: publicIPAllocationMethod
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
          serviceEndpoints: apimSubnetServiceEndpoints
        }
      }
    ]
  }
}

//In addition, regarding deployment lifecycles in workspaces, the APIOps toolkit release 6.0.2 supports automated deployment of workspaces 
//across different environments and enables programmatic workspace management. 
//The management API version 2023-09-01-preview provides this capability.
resource apiManagement 'Microsoft.ApiManagement/service@2023-09-01-preview' = {
  name: apiManagementName
  location: location
  sku: {
    name: sku
    capacity: skuCount
  }
  // add managed identity
  identity: {
    type: 'SystemAssigned'
  }
  //Setting up 'AvailabilityZones' is not supported in Sku :'Developer'
  zones: ((length(availabilityZones) == 0 || sku == 'Developer') ? null : availabilityZones)
  properties: {
    apiVersionConstraint: {
      minApiVersion: '2019-12-01' //minApiVersion is required for APIM -- can make this "202#-##-##" to be more strict
    }
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: 'External'
    publicIpAddressId: publicIp.id
    virtualNetworkConfiguration: {
      subnetResourceId: subnetRef
    }
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_GCM_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'false'
    }
  }

  dependsOn: [
    virtualNetwork
  ]
}

//app insights
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    workspaceCapping: {
      dailyQuotaGb: 1 // '0.023'
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource namedValueAppInsightsSecret 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = {
  parent: apiManagement
  name: 'instrumentationKey'
  properties: {
    tags: []
    secret: true
    keyVault: {
      secretIdentifier: secretAppInsights.properties.secretUri
    }
    displayName: 'instrumentationKey'
  }
  dependsOn: [
    keyVaultRoleAssignment
  ]
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2023-09-01-preview' = {
  parent: apiManagement
  name: applicationInsightsLoggerName
  properties: {
    resourceId: applicationInsights.id
    description: 'Application Insights for APIM'
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: '{{instrumentationKey}}'
    }
  }
  dependsOn: [
    namedValueAppInsightsSecret
  ]
}

// Create a Key Vault instance
resource keyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    sku: {
      name: 'standard'
      family: 'A'
    }
    tenantId: tenant().tenantId
  }
}

// assign RBAC role Key Vault Secrets User to the managed identity of the API Management service
resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().subscriptionId, keyVaultName, apiManagement.name)
  scope: keyVault
  properties: {
    principalId: apiManagement.identity.principalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'
    )
  }
}

// Create a Secret within the KeyVault
resource secretAppInsights 'Microsoft.KeyVault/vaults/secrets@2024-04-01-preview' = {
  name: 'AppInsightsKeyApim'
  parent: keyVault
  properties: {
    value: applicationInsights.properties.InstrumentationKey
  }
}

//create workspace
resource workspace001 'Microsoft.ApiManagement/service/workspaces@2023-09-01-preview' = {
  name: 'WorkspaceApiTeam001'
  parent: apiManagement
  properties: {
    description: 'Workspace for API Team 001'
    displayName: 'Workspace API Team 001'
  }
}

//create workspace
resource workspace002 'Microsoft.ApiManagement/service/workspaces@2023-09-01-preview' = {
  name: 'WorkspaceApiTeam002'
  parent: apiManagement
  properties: {
    description: 'Workspace for API Team 002'
    displayName: 'Workspace API Team 002'
  }
}

// resource gateway 'Microsoft.ApiManagement/service/gateways@2023-09-01-preview' = {
//   parent: apiManagement
//   name: '<gateway-name>'
//   properties: {
//     description: 'Gateway for workspace'
//     locationData: {
//       name: '<location>'
//     }
//   }
// }

// resource gateway001 'Microsoft.ApiManagement/service/gateways@2023-09-01-preview' = if (deployGateway001) {
//   parent: apiManagement
//   name: 'GatewayWorkspaceApiTeam001${environmentName}${instanceNumber}'
//   location: location
//   sku: {
//     name: 'WorkspaceGatewayPremium'
//     capacity: 1
//   }
//   properties: {
//     virtualNetworkType: 'None'
//   }
//   dependsOn: [
//     workspace001
//   ]
// }

// create a gateway for workspace001
// takes 3+ hours to deploy
module gateway001 'modules/gateway.bicep' = if (deployGateway001) {
  name: 'gateway001${environmentName}${instanceNumber}'
  params: {
    location: location
    //workspaceId: workspace001.id
    gatewayName: 'GatewayWorkspaceApiTeam001${environmentName}${instanceNumber}'
    gatewaySku: 'WorkspaceGatewayPremium'
    gatewayCapacity: 1
    // networkConfigName: substring(
    //   'netCfg001${environmentName}${instanceNumber}-${uniqueString(resourceGroup().id)}',
    //   0,
    //   30
    // )
  }
  dependsOn: [
    workspace001
  ]
}

// resource gateway002 'Microsoft.ApiManagement/service/gateways@2023-09-01-preview' = if (deployGateway002) {
//   parent: apiManagement
//   name: 'GatewayWorkspaceApiTeam002${environmentName}${instanceNumber}'
//   location: location
//   sku: {
//     name: 'WorkspaceGatewayPremium'
//     capacity: 1
//   }
//   properties: {
//     virtualNetworkType: 'None'
//   }
//   dependsOn: [
//     workspace002
//   ]
// }

// create a gateway for workspace002
// takes 3+ hours to deploy
module gateway002 'modules/gateway.bicep' = if (deployGateway002) {
  name: 'gateway002${environmentName}${instanceNumber}'
  params: {
    location: location
    //workspaceId: workspace002.id
    gatewayName: 'GatewayWorkspaceApiTeam002${environmentName}${instanceNumber}'
    gatewaySku: 'WorkspaceGatewayPremium'
    gatewayCapacity: 1
    // networkConfigName: substring(
    //   'netCfg002${environmentName}${instanceNumber}-${uniqueString(resourceGroup().id)}',
    //   0,
    //   30
    // )
  }
  dependsOn: [
    workspace002
  ]
}

// // create a gateway
// //param gatewayWorkspaceApiTeam002Name string = 'WorkspaceApiTeam002'
// resource gatewayWorkspaceApiTeam002 'Microsoft.ApiManagement/gateways@2023-09-01-preview' = {
//   name: workspace002.name // gatewayWorkspaceApiTeam002Name
//   location: location
//   sku: {
//     name: 'WorkspaceGatewayPremium'
//     capacity: 1
//   }
//   properties: {
//     frontend: {}
//     backend: {}
//     virtualNetworkType: 'None'
//   }

//   // resource gatewayWorkspaceApiTeam002ConfigConnection 'configConnections@2023-09-01-preview' = {
//   //   name: substring('WrkspcApiTeam002-${uniqueString(resourceGroup().id)}', 0, 30)
//   //   properties: {
//   //     //sourceId: '${service_apim_dev_005_3snpbfdd5kffc_externalid}/workspaces/WorkspaceApiTeam002'
//   //   }
//   // }
// }

// // create a gateway
// //param gatewayWorkspaceApiTeam001Name string = 'WorkspaceApiTeam001'
// resource gatewayWorkspaceApiTeam001 'Microsoft.ApiManagement/gateways@2023-09-01-preview' = {
//   name: workspace001.name //gatewayWorkspaceApiTeam001Name
//   location: location
//   sku: {
//     name: 'WorkspaceGatewayPremium'
//     capacity: 1
//   }
//   properties: {
//     frontend: {}
//     backend: {}
//     virtualNetworkType: 'None'
//   }

//   // resource gatewayWorkspaceApiTeam001ConfigConnection 'configConnections@2023-09-01-preview' = {
//   //   name: substring('WrkspcApiTeam001-${uniqueString(resourceGroup().id)}', 0, 30)
//   //   properties: {
//   //     //sourceId: '${service_apim_dev_005_3snpbfdd5kffc_externalid}/workspaces/WorkspaceApiTeam001'
//   //   }
//   // }
// }

//link app insights to APIM and APIs
//https://mindbyte.nl/2021/05/14/link-appinsights-to-api-management-using-bicep.html

output apiManagementName string = apiManagement.name
output apiManagementId string = apiManagement.id
//output apiManagementAdminUrl string = apiManagement.properties.portalUrl
//output apiManagementServiceUrl string = apiManagement.properties.gatewayUrl
//output apiManagementSubscriptionKey string = listKeys(apiManagement.id, '2019-12-01').primaryKey
output applicationInsightsName string = applicationInsights.name
output applicationInsightsId string = applicationInsights.id
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output publicIpName string = publicIp.name
output publicIpId string = publicIp.id
output virtualNetworkName string = virtualNetwork.name
output virtualNetworkId string = virtualNetwork.id
output subnetName string = subnetName
output subnetId string = subnetRef
output networkSecurityGroupName string = networkSecurityGroup.name
output networkSecurityGroupId string = networkSecurityGroup.id
output keyVaultName string = keyVault.name
output keyVaultId string = keyVault.id
output managedIdentityId string = apiManagement.identity.principalId
