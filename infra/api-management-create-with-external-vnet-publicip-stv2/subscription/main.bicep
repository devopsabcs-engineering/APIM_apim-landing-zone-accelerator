// az deployment group create --resource-group rg-apim-vnet-external-prod-002 --name subscriptionsMethod2 `
//   --template-file ..\infra\api-management-create-with-external-vnet-publicip-stv2\subscription\main.bicep `
//   --parameters ..\infra\api-management-create-with-external-vnet-publicip-stv2\subscription\main.parameters.prod.json

@description('apim Service Name')
param apimServiceName string

resource existingApimService 'Microsoft.ApiManagement/service@2022-08-01' existing = {
  name: apimServiceName
}

//Method2: alternative way to create AAD groups
param subscriptionConfigurations array = [
  {
    ownerId: '/subscriptions/64c3d212-40ed-4c6d-a825-6adfbdf25dad/resourceGroups/rg-apim-vnet-external-prod-002/providers/Microsoft.ApiManagement/service/apim-257jlvys5ho6o/users/642b045c5ddd170e407df558'
    scope: '/subscriptions/64c3d212-40ed-4c6d-a825-6adfbdf25dad/resourceGroups/rg-apim-vnet-external-prod-002/providers/Microsoft.ApiManagement/service/apim-257jlvys5ho6o/products/b2c010product'
    displayName: 'Subscription for B2c 010'
    name: 'b2c010subscription'
  }
  {
    ownerId: '/subscriptions/64c3d212-40ed-4c6d-a825-6adfbdf25dad/resourceGroups/rg-apim-vnet-external-prod-002/providers/Microsoft.ApiManagement/service/apim-257jlvys5ho6o/users/642b079e5ddd170e407df565'
    scope: '/subscriptions/64c3d212-40ed-4c6d-a825-6adfbdf25dad/resourceGroups/rg-apim-vnet-external-prod-002/providers/Microsoft.ApiManagement/service/apim-257jlvys5ho6o/products/b2c011product'
    displayName: 'Subscription for B2c 011'
    name: 'b2c011subscription'
  }
]

resource subscriptionResourcesMethod2 'Microsoft.ApiManagement/service/subscriptions@2022-08-01' = [for (subscriptionConfig, i) in subscriptionConfigurations: {
  name: subscriptionConfig.name
  parent: existingApimService
  properties: {
    //primaryKey: 'string'    
    //secondaryKey: 'string'

    ownerId: contains(subscriptionConfig, 'ownerId') ? subscriptionConfig.ownerId : null
    scope: subscriptionConfig.scope
    displayName: subscriptionConfig.displayName
    state: 'active'
    allowTracing: false
  }
}]
