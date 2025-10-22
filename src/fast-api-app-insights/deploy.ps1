param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = 'rg-fast-api-app-insights-001',

    [Parameter(Mandatory = $false)]
    [string]$Location = 'canadacentral',

    [Parameter(Mandatory = $false)]
    [string]$AppName = 'fast-api-app-insights-001',

    [string]$SubscriptionId,
    [string]$SkuName = 'B1',
    [string]$SkuTier = 'Basic',
    [int]$SkuCapacity = 1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command -Name az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI (az) is not installed or not on PATH.'
}

$null = az account show --only-show-errors

if ($SubscriptionId) {
    az account set --subscription $SubscriptionId --only-show-errors | Out-Null
}

$bicepFile = Join-Path -Path $PSScriptRoot -ChildPath 'main.bicep'
if (-not (Test-Path -Path $bicepFile)) {
    throw "Could not find template file at $bicepFile."
}

$existsRaw = az group exists --name $ResourceGroupName --only-show-errors
if (-not [bool]::Parse($existsRaw)) {
    az group create --name $ResourceGroupName --location $Location --only-show-errors | Out-Null
}

$deployment = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file $bicepFile `
    --parameters appName=$AppName location=$Location skuName=$SkuName skuTier=$SkuTier skuCapacity=$SkuCapacity `
    --only-show-errors `
    --query properties.outputs | ConvertFrom-Json

Write-Host "Deployment complete." -ForegroundColor Green
Write-Host "Web app URL: $($deployment.webAppUrl.value)"
Write-Host "App Insights connection string: $($deployment.appInsightsConnectionString.value)"
Write-Host "App Insights instrumentation key: $($deployment.appInsightsInstrumentationKey.value)"
