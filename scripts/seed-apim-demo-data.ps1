<#
.SYNOPSIS
    Seeds demo users and product subscriptions in an APIM instance.
.DESCRIPTION
    Creates a demo admin user and subscriptions for built-in products
    (Starter, Unlimited) via Azure REST API. Outputs subscription keys.
.PARAMETER ResourceGroup
    The resource group containing the APIM instance.
.PARAMETER ApimName
    The name of the APIM service instance.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ResourceGroup,

    [Parameter(Mandatory)]
    [string]$ApimName
)

$ErrorActionPreference = 'Stop'

$apiVersion = '2024-06-01-preview'
$subscriptionId = (az account show --query id -o tsv)
$basePath = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$ApimName"

Write-Host "Seeding demo data for APIM: $ApimName in resource group: $ResourceGroup"

# --- Create demo admin user ---
$userId = 'demo-admin'
$userPath = "$basePath/users/${userId}?api-version=$apiVersion"

$userBody = @{
    properties = @{
        firstName = 'Demo'
        lastName  = 'Admin'
        email     = "demo-admin@$ApimName.apim.net"
        state     = 'active'
    }
} | ConvertTo-Json -Depth 5

Write-Host "Creating demo admin user..."
az rest --method put --url "https://management.azure.com${userPath}" --body $userBody --headers 'Content-Type=application/json' -o json 2>&1 | Out-Null
Write-Host "  User '$userId' created or already exists."

# --- Discover published products ---
$productsUrl = "https://management.azure.com${basePath}/products?api-version=$apiVersion"
$productsJson = az rest --method get --url $productsUrl -o json | ConvertFrom-Json
$products = $productsJson.value | Where-Object { $_.properties.state -eq 'published' }

if (-not $products -or $products.Count -eq 0) {
    Write-Host "No published products found. Skipping subscription creation."
    exit 0
}

Write-Host "Found $($products.Count) published product(s)."

# --- Create subscriptions for each product ---
$subscriptionKeys = @()

foreach ($product in $products) {
    $productName = $product.name
    $productDisplayName = $product.properties.displayName
    $subName = "demo-sub-$productName"
    $subPath = "$basePath/subscriptions/${subName}?api-version=$apiVersion"

    $subBody = @{
        properties = @{
            displayName = "Demo - $productDisplayName"
            scope       = "/products/$productName"
            ownerId     = "/users/$userId"
            state       = 'active'
        }
    } | ConvertTo-Json -Depth 5

    Write-Host "Creating subscription '$subName' for product '$productDisplayName'..."
    az rest --method put --url "https://management.azure.com${subPath}" --body $subBody --headers 'Content-Type=application/json' -o json 2>&1 | Out-Null

    # Retrieve subscription keys
    $keysUrl = "https://management.azure.com${basePath}/subscriptions/${subName}/listSecrets?api-version=$apiVersion"
    $keysJson = az rest --method post --url $keysUrl -o json 2>$null | ConvertFrom-Json

    if ($keysJson) {
        $subscriptionKeys += [PSCustomObject]@{
            Product      = $productDisplayName
            Subscription = $subName
            PrimaryKey   = $keysJson.primaryKey
            SecondaryKey = $keysJson.secondaryKey
        }
    }
}

# --- Output results ---
Write-Host ""
Write-Host "=== Demo Data Seeding Complete ==="
Write-Host ""

if ($subscriptionKeys.Count -gt 0) {
    Write-Host "Subscription Keys:"
    $subscriptionKeys | Format-Table -AutoSize
} else {
    Write-Host "No subscription keys retrieved."
}
