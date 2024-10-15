param location string = resourceGroup().location
param workspaceId string
param gatewayName string = 'GatewayWorkspaceApiTeam001'
param gatewaySku string = 'WorkspaceGatewayPremium'
param gatewayCapacity int = 1
param networkConfigName string

resource gateway 'Microsoft.ApiManagement/gateways@2023-09-01-preview' = {
  name: gatewayName
  location: location
  sku: {
    name: gatewaySku
    capacity: gatewayCapacity
  }
  properties: {
    virtualNetworkType: 'None'
  }
}

resource gatewayName_networkConfig 'Microsoft.ApiManagement/gateways/configConnections@2023-09-01-preview' = {
  parent: gateway
  name: '${networkConfigName}'
  properties: {
    sourceId: workspaceId
  }
}
