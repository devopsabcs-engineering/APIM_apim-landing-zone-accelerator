// az deployment group create --resource-group rg-apim-vnet-external-prod-002 --name aadIdentityProvider `
//   --template-file ..\infra\api-management-create-with-external-vnet-publicip-stv2\identityProvider\main.bicep `
//   --parameters ..\infra\api-management-create-with-external-vnet-publicip-stv2\identityProvider\main.parameters.prod.json `
//   --parameters clientSecret="iOM8Q*******"

@description('apim Service Name')
param apimServiceName string

@description('signinTenant')
param signinTenant string //= 'mngenv019702.com'

@minLength(1)
//@maxLength(5)
param allowedTenants array = [
  'testekb2c010.onmicrosoft.com'
  'testekb2c011.onmicrosoft.com'
  'mngenv019702.com'
  'devopsabcs.com'
]

param clientId string

@secure()
param clientSecret string

var authority = 'login.windows.net'

resource existingApimService 'Microsoft.ApiManagement/service@2022-08-01' existing = {
  name: apimServiceName
}

resource symbolicname 'Microsoft.ApiManagement/service/identityProviders@2022-08-01' = {
  name: 'aad'
  parent: existingApimService
  properties: {
    allowedTenants: allowedTenants
    authority: authority
    clientId: clientId
    clientLibrary: 'MSAL-2'
    clientSecret: clientSecret
    //passwordResetPolicyName: 'string'
    //profileEditingPolicyName: 'string'
    //signinPolicyName: 'string'
    signinTenant: signinTenant
    //signupPolicyName: 'string'
    type: 'aad'
  }
}
