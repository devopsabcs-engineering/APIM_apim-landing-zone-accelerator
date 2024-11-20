# deploy infrastructure via bicep
param (
    [string]$resourceGroupName = "rg-starwars-appservice-003",
    [string]$location = "eastus2",
    [string]$baseName = "star-wars-api",
    [string]$imageName = "starwarsapi",
    $deploymentName = "infra-deployment"
)

Write-Output "Deploying infrastructure for $baseName in $location"
az group create --name $resourceGroupName `
    --location $location

Write-Output "Deploying infrastructure for $baseName in $location"
az deployment group create --name $deploymentName `
    --resource-group $resourceGroupName `
    --template-file main.bicep `
    --parameters baseName=$baseName `
    --parameters imageName=$imageName

Write-Output "Infrastructure deployed for $baseName in $location"

# get container registry name from deployment output
$acrName = az deployment group show --name $deploymentName `
    --resource-group $resourceGroupName `
    --query properties.outputs.containerRegistryName.value `
    --output tsv

Write-Output "ACR Name: $acrName"

# get app service name from deployment output
$appServiceName = az deployment group show --name $deploymentName `
    --resource-group $resourceGroupName `
    --query properties.outputs.appName.value `
    --output tsv

Write-Output "App Service Name: $appServiceName"