//targetScope = 'resourceGroup'

//az deployment group create --resource-group rg-apim-vnet-external-dev-002 --name oauth009 --template-fil ..\infra\api-management-create-with-external-vnet-publicip-stv2\oauth-server\main.bicep --parameters apimServiceName=apim-bcpcue6zklgaw oauthServerForDevPortalName=b2c009devoauthserver B2cTenantName=testekb2c009 environmentName=dev backendClientId=72a0ba86-2c80-4f01-acc1-c139e912078f frontendClientId=1b7c27aa-709d-4bb3-944a-73d8147933a7 frontendClientSecret="iOM8Q~Irw4MHcuNtxoZTzhk.kZFsm5p2Rkg.vdcd"

@description('apim Service Name')
param apimServiceName string

// @description('apimResourceGroupName')
// param apimResourceGroupName string

@description('oauthServerForDevPortalName')
param oauthServerForDevPortalName string //= 'b2c008devoauthserver'

//param B2cTenantName string //= 'testekb2c008'

param environmentName string //= 'dev' or 'prd'

param clientRegistrationEndpoint string = 'http://localhost'

//param backendClientId string

param frontendClientId string //frontend apim appregistration
@secure()
param frontendClientSecret string

//var userFlowId = 'frontendapp_${environmentName}_signupandsignin'
//var defaultScope = 'https://${B2cTenantName}.onmicrosoft.com/${backendClientId}/Hello' //for backend

param authorizationEndpoint string //= 'https://${B2cTenantName}.b2clogin.com/${B2cTenantName}.onmicrosoft.com/oauth2/v2.0/authorize?p=b2c_1_${userFlowId}'
param tokenEndpoint string //= 'https://${B2cTenantName}.b2clogin.com/${B2cTenantName}.onmicrosoft.com/oauth2/v2.0/token?p=b2c_1_${userFlowId}'
param defaultScope string //= 'https://${B2cTenantName}.onmicrosoft.com/${backendClientId}/Hello' //for backend

resource existingApimService 'Microsoft.ApiManagement/service@2022-08-01' existing = {
  name: apimServiceName
  //scope: resourceGroup(apimResourceGroupName)
}

resource oauthServerForDevPortal 'Microsoft.ApiManagement/service/authorizationServers@2022-08-01' = {
  name: oauthServerForDevPortalName
  parent: existingApimService
  properties: {
    authorizationEndpoint: authorizationEndpoint
    authorizationMethods: [
      'GET'
    ]
    bearerTokenSendingMethods: [
      'authorizationHeader'
    ]
    clientAuthenticationMethod: [
      'Body'
    ]
    clientId: frontendClientId
    clientRegistrationEndpoint: clientRegistrationEndpoint
    clientSecret: frontendClientSecret
    defaultScope: defaultScope
    description: 'oauth server ${environmentName}'
    displayName: oauthServerForDevPortalName
    grantTypes: [
      'authorizationCode'
      'authorizationCodeWithPkce'
    ]
    //resourceOwnerPassword: 'string'
    //resourceOwnerUsername: 'string'
    supportState: false
    tokenBodyParameters: [
      // {
      //   name: 'string'
      //   value: 'string'
      // }
    ]
    tokenEndpoint: tokenEndpoint
    useInApiDocumentation: false
    useInTestConsole: true
  }
}
