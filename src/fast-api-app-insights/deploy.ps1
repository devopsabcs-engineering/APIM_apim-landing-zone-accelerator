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

Set-Location -Path $PSScriptRoot

Write-Host 'Checking Azure CLI login...' -ForegroundColor Cyan

try {
    $accountContext = az account show --only-show-errors | ConvertFrom-Json
} catch {
    Write-Error "Unable to determine the active Azure subscription. Run 'az login' and try again."
    throw
}

if ($SubscriptionId) {
    az account set --subscription $SubscriptionId --only-show-errors | Out-Null
    $accountContext = az account show --only-show-errors | ConvertFrom-Json
}

Write-Host "Using subscription: $($accountContext.id)" -ForegroundColor DarkGray

$bicepFile = Join-Path -Path $PSScriptRoot -ChildPath 'main.bicep'
if (-not (Test-Path -Path $bicepFile)) {
    throw "Could not find template file at $bicepFile."
}

$existsRaw = az group exists --name $ResourceGroupName --only-show-errors
if (-not [bool]::Parse($existsRaw)) {
    Write-Host "Creating resource group '$ResourceGroupName' in $Location..." -ForegroundColor Cyan
    az group create --name $ResourceGroupName --location $Location --only-show-errors | Out-Null
} else {
    Write-Host "Resource group '$ResourceGroupName' already exists." -ForegroundColor DarkGray
}

$packageRoot = Join-Path -Path $PSScriptRoot -ChildPath 'publish'
if (Test-Path -Path $packageRoot) {
    Remove-Item -Path $packageRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $packageRoot | Out-Null

$packageContentDir = Join-Path -Path $packageRoot -ChildPath 'package'
New-Item -ItemType Directory -Path $packageContentDir | Out-Null

Write-Host 'Deploying infrastructure (this can take a few minutes)...' -ForegroundColor Cyan

$deployment = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file $bicepFile `
    --parameters appName=$AppName location=$Location skuName=$SkuName skuTier=$SkuTier skuCapacity=$SkuCapacity `
    --only-show-errors `
    --query properties.outputs | ConvertFrom-Json
$filesToInclude = @('main.py', 'telemetry.py', 'requirements.txt', 'README.md')
foreach ($relativePath in $filesToInclude) {
    $sourcePath = Join-Path -Path $PSScriptRoot -ChildPath $relativePath
    if (Test-Path -Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination $packageContentDir -Recurse -Force
    }
}

$requirementsPath = Join-Path -Path $PSScriptRoot -ChildPath 'requirements.txt'
if (Test-Path -Path $requirementsPath) {
    $sitePackagesPath = Join-Path -Path $packageContentDir -ChildPath '.python_packages/lib/site-packages'
    if (-not (Test-Path -Path $sitePackagesPath)) {
        New-Item -ItemType Directory -Path $sitePackagesPath -Force | Out-Null
    }

    $venvPythonCandidates = @(
        (Join-Path -Path $PSScriptRoot -ChildPath '.venv\Scripts\python.exe')
        (Join-Path -Path $PSScriptRoot -ChildPath '.venv/bin/python')
    )

    $venvPython = $venvPythonCandidates | Where-Object { Test-Path -Path $_ } | Select-Object -First 1
    if (-not $venvPython) {
        $venvPython = 'python'
    }

    Write-Host 'Bundling dependencies into .python_packages...' -ForegroundColor Cyan
    try {
        & $venvPython -m pip install --upgrade --target $sitePackagesPath -r $requirementsPath --no-compile
    } catch {
        Write-Error "Failed to bundle dependencies: $_"
        throw
    }
} else {
    Write-Warning 'No requirements.txt found; skipping dependency bundling.'
}

$packagePath = Join-Path -Path $packageRoot -ChildPath 'app.zip'
if (Test-Path -Path $packagePath) {
    Remove-Item -Path $packagePath -Force
}
Write-Host 'Packaging application artifacts...' -ForegroundColor Cyan
Compress-Archive -Path (Join-Path $packageContentDir '*') -DestinationPath $packagePath -Force

Write-Host 'Publishing ZIP package to Web App...' -ForegroundColor Cyan
az webapp deploy `
    --resource-group $ResourceGroupName `
    --name $AppName `
    --src-path $packagePath `
    --type zip `
    --build-remote true `
    --only-show-errors | Out-Null

Write-Host 'Cleaning up local staging artifacts...' -ForegroundColor DarkGray
Remove-Item -Path $packageRoot -Recurse -Force

Write-Host "Deployment complete." -ForegroundColor Green
Write-Host "Web app URL: $($deployment.webAppUrl.value)"
Write-Host "App Insights connection string: $($deployment.appInsightsConnectionString.value)"
Write-Host "App Insights instrumentation key: $($deployment.appInsightsInstrumentationKey.value)"
