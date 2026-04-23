<#
.SYNOPSIS
    Creates/rotates app registration secrets and stores them in the ADO variable group
    and Azure Key Vault for the APIM lab environment.

.DESCRIPTION
    This script handles four app registrations:
    1. OBO-storage-dotnet (.NET WebApp) - b72949d1-b1f4-41cc-a370-5fa5f4e40d10
    2. WebApp-python-flask-frontend - 239749a9-dccf-4e6b-b13c-ed390b53cc9b
    3. APIM Dev Portal AAD Provider (apim-dev-006) - a6994ee8-cb93-4aad-b62a-9db167e8cf8b
    4. WebApp-python-flask-backend (resource server) - c2847e0f-04c0-4ee4-9349-72c7fceb0161 (no secret needed)

    It creates fresh secrets for #1-#3 and stores them in:
    - ADO variable group: APIM_rg-apim-vnet-external-dev-006 (ID 131)
    - Azure Key Vault: used by Flask app Bicep deployment

.PARAMETER AdoPat
    Azure DevOps Personal Access Token with Variable Groups (Read & Manage) scope.

.PARAMETER SkipSecretRotation
    If set, skips creating new secrets and only updates ADO variables with existing env values.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$AdoPat,

    [switch]$SkipSecretRotation
)

$ErrorActionPreference = 'Stop'

# ── Config ────────────────────────────────────────────────────────────────────
$org = "https://dev.azure.com/devopsabcs"
$project = "OneProject"
$variableGroupId = 131
$variableGroupName = "APIM_rg-apim-vnet-external-dev-006"

$dotnetAppId = "b72949d1-b1f4-41cc-a370-5fa5f4e40d10"
$flaskFrontendAppId = "239749a9-dccf-4e6b-b13c-ed390b53cc9b"
$apimDevPortalAppId = "a6994ee8-cb93-4aad-b62a-9db167e8cf8b"

$tenantId = (az account show --query tenantId -o tsv)
$domain = "MngEnvMCAP675646.onmicrosoft.com"

Write-Host "Tenant ID: $tenantId"
Write-Host "Domain: $domain"
Write-Host ""

# ── Step 1: Create fresh secrets ──────────────────────────────────────────────
if (-not $SkipSecretRotation) {
    $dateLabel = Get-Date -Format 'yyyyMMdd'

    Write-Host "Creating secret for .NET WebApp ($dotnetAppId)..."
    $dotnetSecret = az ad app credential reset --id $dotnetAppId `
        --display-name "lab-pipeline-$dateLabel" --years 2 `
        --query password -o tsv
    Write-Host "  OK: $($dotnetSecret.Substring(0,4))****"

    Write-Host "Creating secret for Flask Frontend ($flaskFrontendAppId)..."
    $flaskSecret = az ad app credential reset --id $flaskFrontendAppId `
        --display-name "lab-pipeline-$dateLabel" --years 2 `
        --query password -o tsv
    Write-Host "  OK: $($flaskSecret.Substring(0,4))****"

    Write-Host "Creating secret for APIM Dev Portal ($apimDevPortalAppId)..."
    $apimDevSecret = az ad app credential reset --id $apimDevPortalAppId `
        --display-name "lab-pipeline-$dateLabel" --years 2 `
        --query password -o tsv
    Write-Host "  OK: $($apimDevSecret.Substring(0,4))****"
}
else {
    Write-Host "Skipping secret rotation (using existing values from environment)."
    $dotnetSecret = $env:DOTNET_SECRET
    $flaskSecret = $env:FLASK_SECRET
    $apimDevSecret = $env:APIM_DEV_SECRET
}

Write-Host ""

# ── Step 2: Configure redirect URIs for .NET WebApp ──────────────────────────
Write-Host "Configuring redirect URIs for .NET WebApp..."
# Get the current web app name from the resource group (if it exists)
$webAppName = az deployment group show `
    --name "infra-deployment" `
    --resource-group "rg-web-appservice-linux-005" `
    --query "properties.outputs.appName.value" -o tsv 2>$null

if ($webAppName) {
    $appUrl = "https://${webAppName}.azurewebsites.net"
    Write-Host "  Adding redirect URI: $appUrl/signin-oidc"
    az ad app update --id $dotnetAppId `
        --web-redirect-uris "https://localhost:44321/signin-oidc" "https://localhost:44321/" "$appUrl/signin-oidc" "$appUrl/" `
        2>$null
    Write-Host "  OK"
}
else {
    Write-Host "  Web app not deployed yet - will configure redirect URIs after deployment."
    az ad app update --id $dotnetAppId `
        --web-redirect-uris "https://localhost:44321/signin-oidc" "https://localhost:44321/" `
        2>$null
}

# ── Step 3: Configure redirect URIs for Flask Frontend ────────────────────────
Write-Host "Configuring redirect URIs for Flask Frontend..."
$flaskAppName = az deployment group show `
    --name "infra-deployment" `
    --resource-group "rg-msal-python-soln" `
    --query "properties.outputs.webAppName.value" -o tsv 2>$null

if ($flaskAppName) {
    $flaskUrl = "https://${flaskAppName}.azurewebsites.net"
    Write-Host "  Adding redirect URI: $flaskUrl/getAToken"
    az ad app update --id $flaskFrontendAppId `
        --web-redirect-uris "http://localhost:5000/getAToken" "$flaskUrl/getAToken" `
        2>$null
    Write-Host "  OK"
}
else {
    Write-Host "  Flask app not deployed yet - will configure redirect URIs after deployment."
    az ad app update --id $flaskFrontendAppId `
        --web-redirect-uris "http://localhost:5000/getAToken" `
        2>$null
}

Write-Host ""

# ── Step 4: Update ADO Variable Group ─────────────────────────────────────────
Write-Host "Updating ADO variable group ($variableGroupName)..."

$env:AZURE_DEVOPS_EXT_PAT = $AdoPat
az devops configure --defaults organization=$org project=$project

# Variables to add/update (secrets are marked as isSecret)
$varsToAdd = @(
    @{ name = "azureAdClientId"; value = $dotnetAppId; isSecret = $false },
    @{ name = "azureAdClientSecret"; value = $dotnetSecret; isSecret = $true },
    @{ name = "azureAdDomain"; value = $domain; isSecret = $false },
    @{ name = "flaskClientId"; value = $flaskFrontendAppId; isSecret = $false },
    @{ name = "flaskClientSecret"; value = $flaskSecret; isSecret = $true },
    @{ name = "aadProviderClientId"; value = $apimDevPortalAppId; isSecret = $false },
    @{ name = "aadProviderClientSecret"; value = $apimDevSecret; isSecret = $true }
)

foreach ($var in $varsToAdd) {
    $secretFlag = if ($var.isSecret) { "--secret true" } else { "" }
    Write-Host "  Setting $($var.name)$(if ($var.isSecret) { ' (secret)' } else { '' })..."

    # Try update first, then create if it doesn't exist
    $result = az pipelines variable-group variable update `
        --group-id $variableGroupId `
        --name $var.name `
        --value $var.value `
        $(if ($var.isSecret) { '--secret', 'true' }) `
        2>&1

    if ($LASTEXITCODE -ne 0) {
        az pipelines variable-group variable create `
            --group-id $variableGroupId `
            --name $var.name `
            --value $var.value `
            $(if ($var.isSecret) { '--secret', 'true' }) `
            2>&1 | Out-Null
    }
    Write-Host "    OK"
}

Write-Host ""

# ── Step 5: Store Flask secret in Key Vault (if KV exists) ────────────────────
Write-Host "Checking for Flask Key Vault..."
$kvName = az keyvault list --resource-group "rg-msal-python-soln" `
    --query "[0].name" -o tsv 2>$null

if ($kvName) {
    Write-Host "  Storing Flask client secret in Key Vault: $kvName"
    az keyvault secret set --vault-name $kvName `
        --name "flask-client-secret" `
        --value $flaskSecret `
        --output none 2>$null
    Write-Host "  OK"
}
else {
    Write-Host "  Key Vault not found in rg-msal-python-soln - will be created during deployment."
}

Write-Host ""
Write-Host "=== Setup Complete ==="
Write-Host ""
Write-Host "App Registrations configured:"
Write-Host "  .NET WebApp:       $dotnetAppId"
Write-Host "  Flask Frontend:    $flaskFrontendAppId"
Write-Host "  APIM Dev Portal:   $apimDevPortalAppId"
Write-Host ""
Write-Host "ADO Variable Group: $variableGroupName (ID: $variableGroupId)"
Write-Host "  azureAdClientId, azureAdClientSecret, azureAdDomain"
Write-Host "  flaskClientId, flaskClientSecret"
Write-Host "  aadProviderClientId, aadProviderClientSecret"
