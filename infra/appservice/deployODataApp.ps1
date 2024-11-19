# deploy infrastructure via bicep
param (
    [string]$resourceGroupName = "rg-odata-appservice-001",
    [string]$location = "eastus2",
    [string]$baseName = "odata-api",
    [string]$imageName = "odataapi",
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