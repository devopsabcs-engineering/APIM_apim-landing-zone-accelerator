# deploy infrastructure via bicep
param (
    [string]$instanceNumber = "002",
    [string]$resourceGroupName = "rg-appt-fnapp-$instanceNumber",
    [string]$location = "canadacentral"
)

$deploymentName = "infra-deployment"
az group create --name $resourceGroupName `
    --location $location

az deployment group create --name $deploymentName `
    --resource-group $resourceGroupName `
    --template-file main.bicep `
    --parameters instanceNumber=$instanceNumber

# get the storage account name from the deployment
$storageAccountName = az deployment group show --name $deploymentName `
    --resource-group $resourceGroupName `
    --query properties.outputs.storageAccountName.value `
    --output tsv

Write-Host "Storage Account Name: $storageAccountName"

# get the function app name from the deployment
$functionAppName = az deployment group show --name $deploymentName `
    --resource-group $resourceGroupName `
    --query properties.outputs.functionAppName.value `
    --output tsv

Write-Host "Function App Name: $functionAppName"

# get the app insights name from the deployment
$appInsightsName = az deployment group show --name $deploymentName `
    --resource-group $resourceGroupName `
    --query properties.outputs.applicationInsightsName.value `
    --output tsv

Write-Host "App Insights Name: $appInsightsName"

# get container registry name from the deployment
$containerRegistryName = az deployment group show --name $deploymentName `
    --resource-group $resourceGroupName `
    --query properties.outputs.containerRegistryName.value `
    --output tsv

Write-Host "Container Registry Name: $containerRegistryName"