// az deployment group create --resource-group rg-apim-vnet-external-prod-002 --name aadGroupsMethod1 `
//   --template-file ..\infra\api-management-create-with-external-vnet-publicip-stv2\group\main.bicep `
//   --parameters ..\infra\api-management-create-with-external-vnet-publicip-stv2\group\main.parameters.prod.json

@description('apim Service Name')
param apimServiceName string

resource existingApimService 'Microsoft.ApiManagement/service@2022-08-01' existing = {
  name: apimServiceName
}

//Method1: create AAD groups
param groupValues object = {
  group1: {
    name: 'apim-bcpcue6zklgaw-aad-main-group'
    description: 'Main aad group for apim (method1)'
    displayName: 'apim-bcpcue6zklgaw-aad-main-group'
    externalId: 'aad://mngenv019702.com/groups/e7051c55-363a-42ac-9c30-3fcc43a22e39'
    type: 'external'
  }
  group2: {
    name: 'apim-bcpcue6zklgaw-aad-main-group-aad-devopsabcs_com'
    description: 'main group for external apim in mngenv019702 (method1)'
    displayName: 'apim-bcpcue6zklgaw-aad-main-group-aad-devopsabcs_com'
    externalId: 'aad://devopsabcs.com/groups/55b7ec27-9c25-4860-9b15-461c63b0bd1a'
    type: 'external'
  }
  group3: {
    name: 'apim-bcpcue6zklgaw-aad-main-group-b2c-010'
    description: 'for apim apim-bcpcue6zklgaw-aad-main-group for tenant b2c010 (method1)'
    displayName: 'apim-bcpcue6zklgaw-aad-main-group-b2c-010'
    externalId: 'aad://testekb2c010.onmicrosoft.com/groups/b94f3405-a0be-45c7-b590-945c599479e1'
    type: 'external'
  }
  group4: {
    name: 'apim-bcpcue6zklgaw-aad-main-group-b2c-011'
    description: 'for apim apim-bcpcue6zklgaw-aad-main-group for tenant b2c011 (method1)'
    displayName: 'apim-bcpcue6zklgaw-aad-main-group-b2c-011'
    externalId: 'aad://testekb2c011.onmicrosoft.com/groups/9d75c503-d4a9-4e93-99e5-e9f3a71362c8'
    type: 'external'
  }
}

//for AAD groups
resource groupResourcesMethod1 'Microsoft.ApiManagement/service/groups@2022-08-01' = [for group in items(groupValues): {
  name: group.value.name
  parent: existingApimService
  properties: {
    description: group.value.description
    displayName: group.value.displayName
    externalId: group.value.externalId
    type: group.value.type
  }
}]

// //Method2: alternative way to create AAD groups
// var groupConfigurations = [
//   {
//     name: 'apim-bcpcue6zklgaw-aad-main-group'
//     description: 'Main aad group for apim (method2)'
//     displayName: 'apim-bcpcue6zklgaw-aad-main-group'
//     externalId: 'aad://mngenv019702.com/groups/e7051c55-363a-42ac-9c30-3fcc43a22e39'
//     type: 'external'
//   }
//   {
//     name: 'apim-bcpcue6zklgaw-aad-main-group-aad-devopsabcs_com'
//     description: 'main group for external apim in mngenv019702 (method2)'
//     displayName: 'apim-bcpcue6zklgaw-aad-main-group-aad-devopsabcs_com'
//     externalId: 'aad://devopsabcs.com/groups/55b7ec27-9c25-4860-9b15-461c63b0bd1a'
//     type: 'external'
//   }
//   {
//     name: 'apim-bcpcue6zklgaw-aad-main-group-b2c-010'
//     description: 'for apim apim-bcpcue6zklgaw-aad-main-group for tenant b2c010 (method2)'
//     displayName: 'apim-bcpcue6zklgaw-aad-main-group-b2c-010'
//     externalId: 'aad://testekb2c010.onmicrosoft.com/groups/b94f3405-a0be-45c7-b590-945c599479e1'
//     type: 'external'
//   }
//   {
//     name: 'apim-bcpcue6zklgaw-aad-main-group-b2c-011'
//     description: 'for apim apim-bcpcue6zklgaw-aad-main-group for tenant b2c011 (method2)'
//     displayName: 'apim-bcpcue6zklgaw-aad-main-group-b2c-011'
//     externalId: 'aad://testekb2c011.onmicrosoft.com/groups/9d75c503-d4a9-4e93-99e5-e9f3a71362c8'
//     type: 'external'
//   }
// ]

// resource groupResourcesMethod2 'Microsoft.ApiManagement/service/groups@2022-08-01' = [for (groupConfig, i) in groupConfigurations: {
//   name: '${groupConfig.name}${i}'
//   parent: existingApimService
//   properties: {
//     description: groupConfig.description
//     displayName: groupConfig.displayName
//     externalId: groupConfig.externalId
//     type: groupConfig.type
//   }
// }]
