param gateways_WorkspaceApiTeam002_name string = 'WorkspaceApiTeam002'
param service_apim_dev_005_3snpbfdd5kffc_externalid string = '/subscriptions/64c3d212-40ed-4c6d-a825-6adfbdf25dad/resourceGroups/rg-apim-vnet-external-dev-005-eu2/providers/Microsoft.ApiManagement/service/apim-dev-005-3snpbfdd5kffc'

resource gateways_WorkspaceApiTeam002_name_resource 'Microsoft.ApiManagement/gateways@2023-09-01-preview' = {
  name: gateways_WorkspaceApiTeam002_name
  location: 'East US 2'
  sku: {
    name: 'WorkspaceGatewayPremium'
    capacity: 1
  }
  properties: {
    frontend: {}
    backend: {}
    virtualNetworkType: 'None'
  }
}

resource gateways_WorkspaceApiTeam002_name_WorkspaceApiTe_wl84054cq1exlly 'Microsoft.ApiManagement/gateways/configConnections@2023-09-01-preview' = {
  parent: gateways_WorkspaceApiTeam002_name_resource
  name: 'WorkspaceApiTe-wl84054cq1exlly'
  properties: {
    sourceId: '${service_apim_dev_005_3snpbfdd5kffc_externalid}/workspaces/WorkspaceApiTeam002'
  }
}
