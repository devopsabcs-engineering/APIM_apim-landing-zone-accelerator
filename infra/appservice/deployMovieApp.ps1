# deploy infrastructure via bicep
param (
    [string]$resourceGroupName = "rg-movies-appservice",
    [string]$location = "eastus2",
    [string]$baseName = "movie-api",
    [string]$imageName = "movieapi"
)

$deploymentName = "infra-deployment"
az group create --name $resourceGroupName `
    --location $location

az deployment group create --name $deploymentName `
    --resource-group $resourceGroupName `
    --template-file main.bicep `
    --parameters baseName=$baseName `
    --parameters imageName=$imageName