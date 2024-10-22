@description('That name is the name of our application. It has to be unique.Type a name followed by your resource group name. (<name>-<resourceGroupName>)')
param webAppName string = 'app-flask-${uniqueString(resourceGroup().id)}'

@description('Location for all resources.')
param location string = resourceGroup().location

var alwaysOn = false
var sku = 'Free'
var skuCode = 'F1'
var workerSizeId = 0
var numberOfWorkers = 1
var linuxFxVersion = 'PYTHON|3.9'
var hostingPlanName = 'asp-${resourceGroup().name}'

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  properties: {
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      alwaysOn: alwaysOn
    }
    serverFarmId: hostingPlan.id
    clientAffinityEnabled: false
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

output webAppId string = webApp.id
output hostingPlanId string = hostingPlan.id
output webAppName string = webApp.name
