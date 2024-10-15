# deploy infrastructure via bicep
param (
    [string]$resourceGroupName = "rg-weather-appservice",
    [string]$location = "eastus2"
)

$deploymentName = "infra-deployment"
az group create --name $resourceGroupName `
    --location $location

az deployment group create --name $deploymentName `
    --resource-group $resourceGroupName `
    --template-file main.bicep