# deploy infrastructure via bicep
param (
    [string]$resourceGroupName = "rg-soap-appservice",
    [string]$location = "eastus2",
    [string]$baseName = "soap-api",
    [string]$imageName = "soapapi"
)

$deploymentName = "infra-deployment"
az group create --name $resourceGroupName `
    --location $location

az deployment group create --name $deploymentName `
    --resource-group $resourceGroupName `
    --template-file main.bicep `
    --parameters baseName=$baseName `
    --parameters imageName=$imageName