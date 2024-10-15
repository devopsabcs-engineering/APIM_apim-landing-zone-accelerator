// az deployment group create --resource-group rg-apim-vnet-external-prod-002 --name aadUsersMethod2 `
//   --template-file ..\infra\api-management-create-with-external-vnet-publicip-stv2\user\main.bicep `
//   --parameters ..\infra\api-management-create-with-external-vnet-publicip-stv2\user\main.parameters.prod.json

@description('apim Service Name')
param apimServiceName string

resource existingApimService 'Microsoft.ApiManagement/service@2022-08-01' existing = {
  name: apimServiceName
}

//Method2: alternative way to create AAD groups
param userConfigurations array = [
  {
    firstName: 'Thomas'
    lastName: 'SmokeTester010'
    email: 'fb27510a-4e4f-444e-b5ca-3d2ab28db6a1@testekb2c010.onmicrosoft.com'
    userObjectIdInAad: 'f8709fde-a338-4dc2-a5c6-d26df1da77bb'
    type: 'Aad'
  }
  {
    firstName: 'Thomas'
    lastName: 'SmokeTester011'
    email: 'f0ff2ad6-c7ad-4898-915d-d0425ba69dc5@testekb2c011.onmicrosoft.com'
    userObjectIdInAad: 'f74e29b3-d343-491f-b94b-d726e9d0af7e'
    type: 'Aad'
  }
]

resource userResourcesMethod2 'Microsoft.ApiManagement/service/users@2022-08-01' = [for (userConfig, i) in userConfigurations: {
  name: '${userConfig.userObjectIdInAad}'
  parent: existingApimService
  properties: {
    //appType: 'string'
    //confirmation: 'string'
    note: 'Added by Bicep'
    //password: 'string'
    firstName: userConfig.firstName
    lastName: userConfig.lastName
    email: userConfig.email
    state: 'active'
    identities: [
      {
        provider: userConfig.type
        id: userConfig.userObjectIdInAad
      }
    ]
  }
}]
