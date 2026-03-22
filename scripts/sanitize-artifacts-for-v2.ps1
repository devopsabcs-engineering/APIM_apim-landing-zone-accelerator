<#
.SYNOPSIS
    Sanitizes APIops artifact folders for publishing to BasicV2 APIM instances.

.DESCRIPTION
    Cleans v1-specific references from artifact folders before publishing to BasicV2 instances.
    Addresses 8 migration gaps discovered during v1-to-v2 migration:
    1. External AAD groups (type=external)
    2. Product-group associations referencing deleted external groups
    3. Subscriptions with instance-specific user/product references
    4. OAuth2 authenticationSettings in API definitions
    5. Key Vault references in named values
    6. instrumentationKey named value (managed by Bicep)
    7. Workspace artifacts (not supported on BasicV2)
    8. Instance-specific URLs (serviceUrl, developerPortalUrl)

.PARAMETER ArtifactPath
    Root path to the artifact folder to sanitize.

.PARAMETER TargetApimName
    APIM instance name to update URLs to.

.PARAMETER WhatIf
    Preview changes without modifying files.

.EXAMPLE
    ./scripts/sanitize-artifacts-for-v2.ps1 -ArtifactPath "./artifacts" -TargetApimName "apim-dev-006-abc123"

.EXAMPLE
    ./scripts/sanitize-artifacts-for-v2.ps1 -ArtifactPath "./artifacts" -TargetApimName "apim-dev-006-abc123" -WhatIf
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ArtifactPath,

    [Parameter(Mandatory)]
    [string]$TargetApimName,

    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"

if (-not (Test-Path $ArtifactPath)) {
    Write-Error "Artifact path not found: $ArtifactPath"
    return
}

$ArtifactPath = (Resolve-Path $ArtifactPath).Path
$changeCount = 0

Write-Information "=== APIM Artifact Sanitizer for BasicV2 ==="
Write-Information "Artifact path: $ArtifactPath"
Write-Information "Target APIM:   $TargetApimName"
if ($WhatIf) { Write-Information "Mode:          WhatIf (preview only)" }
Write-Information ""

# ---------------------------------------------------------------------------
# 1. Remove external AAD groups (type=external in groupInformation.json)
# ---------------------------------------------------------------------------
Write-Information "--- Step 1: Remove external AAD groups ---"
$groupsPath = Join-Path $ArtifactPath "groups"
if (Test-Path $groupsPath) {
    $groupFolders = Get-ChildItem -Path $groupsPath -Directory
    foreach ($folder in $groupFolders) {
        $infoFile = Join-Path $folder.FullName "groupInformation.json"
        if (Test-Path $infoFile) {
            $groupInfo = Get-Content $infoFile -Raw | ConvertFrom-Json
            if ($groupInfo.properties.type -eq "external") {
                Write-Information "  Removing external group: $($folder.Name)"
                $changeCount++
                if (-not $WhatIf) {
                    Remove-Item -Path $folder.FullName -Recurse -Force
                }
            }
        }
    }
} else {
    Write-Information "  No groups folder found, skipping."
}

# ---------------------------------------------------------------------------
# 2. Remove product-group associations referencing deleted external groups
# ---------------------------------------------------------------------------
Write-Information "--- Step 2: Remove product-group associations for external groups ---"
$productsPath = Join-Path $ArtifactPath "products"
if (Test-Path $productsPath) {
    # Collect remaining group names after step 1
    $remainingGroups = @()
    if (Test-Path $groupsPath) {
        $remainingGroups = (Get-ChildItem -Path $groupsPath -Directory).Name
    }

    $productFolders = Get-ChildItem -Path $productsPath -Directory
    foreach ($product in $productFolders) {
        $productGroupsPath = Join-Path $product.FullName "groups"
        if (Test-Path $productGroupsPath) {
            $groupLinks = Get-ChildItem -Path $productGroupsPath -Directory
            foreach ($groupLink in $groupLinks) {
                # Remove group link if the group no longer exists
                if ($groupLink.Name -notin $remainingGroups) {
                    Write-Information "  Removing group link '$($groupLink.Name)' from product '$($product.Name)'"
                    $changeCount++
                    if (-not $WhatIf) {
                        Remove-Item -Path $groupLink.FullName -Recurse -Force
                    }
                }
            }
            # Remove empty groups folder
            if (-not $WhatIf -and (Test-Path $productGroupsPath)) {
                $remaining = Get-ChildItem -Path $productGroupsPath
                if ($remaining.Count -eq 0) {
                    Remove-Item -Path $productGroupsPath -Force
                }
            }
        }
    }
} else {
    Write-Information "  No products folder found, skipping."
}

# ---------------------------------------------------------------------------
# 3. Remove all subscriptions (contain instance-specific user/product refs)
# ---------------------------------------------------------------------------
Write-Information "--- Step 3: Remove subscriptions ---"
$subscriptionsPath = Join-Path $ArtifactPath "subscriptions"
if (Test-Path $subscriptionsPath) {
    $subFolders = Get-ChildItem -Path $subscriptionsPath -Directory
    foreach ($sub in $subFolders) {
        Write-Information "  Removing subscription: $($sub.Name)"
        $changeCount++
        if (-not $WhatIf) {
            Remove-Item -Path $sub.FullName -Recurse -Force
        }
    }
    # Remove empty subscriptions folder
    if (-not $WhatIf -and (Test-Path $subscriptionsPath)) {
        $remaining = Get-ChildItem -Path $subscriptionsPath
        if ($remaining.Count -eq 0) {
            Remove-Item -Path $subscriptionsPath -Force
        }
    }
} else {
    Write-Information "  No subscriptions folder found, skipping."
}

# ---------------------------------------------------------------------------
# 4. Clear authenticationSettings.oAuth2 from all API apiInformation.json
# ---------------------------------------------------------------------------
Write-Information "--- Step 4: Clear OAuth2 authenticationSettings from APIs ---"
$apisPath = Join-Path $ArtifactPath "apis"
if (Test-Path $apisPath) {
    $apiInfoFiles = Get-ChildItem -Path $apisPath -Recurse -Filter "apiInformation.json"
    foreach ($apiFile in $apiInfoFiles) {
        $content = Get-Content $apiFile.FullName -Raw
        $apiInfo = $content | ConvertFrom-Json
        if ($apiInfo.properties.authenticationSettings.oAuth2) {
            Write-Information "  Clearing OAuth2 from: $($apiFile.FullName | Split-Path -Parent | Split-Path -Leaf)"
            $changeCount++
            if (-not $WhatIf) {
                $apiInfo.properties.authenticationSettings.PSObject.Properties.Remove("oAuth2")
                $apiInfo | ConvertTo-Json -Depth 20 | Set-Content $apiFile.FullName -Encoding UTF8
            }
        }
    }
} else {
    Write-Information "  No apis folder found, skipping."
}

# ---------------------------------------------------------------------------
# 5. Remove Key Vault references from named values, replace with placeholders
# ---------------------------------------------------------------------------
Write-Information "--- Step 5: Remove Key Vault references from named values ---"
$namedValuesPath = Join-Path $ArtifactPath "named values"
if (Test-Path $namedValuesPath) {
    $nvFolders = Get-ChildItem -Path $namedValuesPath -Directory
    foreach ($nv in $nvFolders) {
        $nvFile = Join-Path $nv.FullName "namedValueInformation.json"
        if (Test-Path $nvFile) {
            $nvInfo = Get-Content $nvFile -Raw | ConvertFrom-Json
            if ($nvInfo.properties.PSObject.Properties["keyVault"]) {
                Write-Information "  Replacing Key Vault ref in named value: $($nv.Name)"
                $changeCount++
                if (-not $WhatIf) {
                    $nvInfo.properties.PSObject.Properties.Remove("keyVault")
                    $nvInfo.properties | Add-Member -NotePropertyName "value" -NotePropertyValue "PLACEHOLDER-configure-in-target" -Force
                    $nvInfo.properties.secret = $false
                    $nvInfo | ConvertTo-Json -Depth 20 | Set-Content $nvFile -Encoding UTF8
                }
            }
        }
    }
} else {
    Write-Information "  No 'named values' folder found, skipping."
}

# ---------------------------------------------------------------------------
# 6. Remove instrumentationKey named value folder (managed by Bicep)
# ---------------------------------------------------------------------------
Write-Information "--- Step 6: Remove instrumentationKey named value ---"
$instrumentationKeyPath = Join-Path $namedValuesPath "instrumentationKey"
if (Test-Path $instrumentationKeyPath) {
    Write-Information "  Removing instrumentationKey named value folder"
    $changeCount++
    if (-not $WhatIf) {
        Remove-Item -Path $instrumentationKeyPath -Recurse -Force
    }
} else {
    Write-Information "  instrumentationKey not found, skipping."
}

# ---------------------------------------------------------------------------
# 7. Remove workspace artifacts (not supported on BasicV2)
# ---------------------------------------------------------------------------
Write-Information "--- Step 7: Remove workspace artifacts ---"
$workspacesPath = Join-Path $ArtifactPath "workspaces"
if (Test-Path $workspacesPath) {
    Write-Information "  Removing workspaces folder"
    $changeCount++
    if (-not $WhatIf) {
        Remove-Item -Path $workspacesPath -Recurse -Force
    }
} else {
    Write-Information "  No workspaces folder found, skipping."
}

# ---------------------------------------------------------------------------
# 8. Update instance-specific URLs using -TargetApimName
# ---------------------------------------------------------------------------
Write-Information "--- Step 8: Update instance-specific URLs ---"
$targetGatewayUrl = "https://$TargetApimName.azure-api.net"
$targetDevPortalUrl = "https://$TargetApimName.developer.azure-api.net"

# 8a. Update serviceUrl in apiInformation.json files
if (Test-Path $apisPath) {
    $apiInfoFiles = Get-ChildItem -Path $apisPath -Recurse -Filter "apiInformation.json"
    foreach ($apiFile in $apiInfoFiles) {
        $content = Get-Content $apiFile.FullName -Raw
        $apiInfo = $content | ConvertFrom-Json
        $serviceUrl = $apiInfo.properties.serviceUrl
        if ($serviceUrl -and $serviceUrl -match "https://[^/]+\.azure-api\.net") {
            $newUrl = $serviceUrl -replace "https://[^/]+\.azure-api\.net", $targetGatewayUrl
            if ($newUrl -ne $serviceUrl) {
                Write-Information "  Updating serviceUrl in: $($apiFile.FullName | Split-Path -Parent | Split-Path -Leaf)"
                $changeCount++
                if (-not $WhatIf) {
                    $apiInfo.properties.serviceUrl = $newUrl
                    $apiInfo | ConvertTo-Json -Depth 20 | Set-Content $apiFile.FullName -Encoding UTF8
                }
            }
        }
    }
}

# 8b. Update developerPortalUrl in named values
if (Test-Path $namedValuesPath) {
    $nvFolders = Get-ChildItem -Path $namedValuesPath -Directory
    foreach ($nv in $nvFolders) {
        $nvFile = Join-Path $nv.FullName "namedValueInformation.json"
        if (Test-Path $nvFile) {
            $nvInfo = Get-Content $nvFile -Raw | ConvertFrom-Json
            $val = $nvInfo.properties.value
            if ($val -and $val -match "https://[^/]+\.developer\.azure-api\.net") {
                $newVal = $val -replace "https://[^/]+\.developer\.azure-api\.net", $targetDevPortalUrl
                if ($newVal -ne $val) {
                    Write-Information "  Updating developer portal URL in named value: $($nv.Name)"
                    $changeCount++
                    if (-not $WhatIf) {
                        $nvInfo.properties.value = $newVal
                        $nvInfo | ConvertTo-Json -Depth 20 | Set-Content $nvFile -Encoding UTF8
                    }
                }
            }
        }
    }
}

# 8c. Update URLs in policy.xml files
$policyFiles = Get-ChildItem -Path $ArtifactPath -Recurse -Filter "policy.xml"
foreach ($policyFile in $policyFiles) {
    $content = Get-Content $policyFile.FullName -Raw
    $updated = $content -replace "https://[a-zA-Z0-9_-]+\.azure-api\.net", $targetGatewayUrl
    $updated = $updated -replace "https://[a-zA-Z0-9_-]+\.developer\.azure-api\.net", $targetDevPortalUrl
    if ($updated -ne $content) {
        Write-Information "  Updating URLs in: $($policyFile.FullName.Substring($ArtifactPath.Length + 1))"
        $changeCount++
        if (-not $WhatIf) {
            Set-Content -Path $policyFile.FullName -Value $updated -Encoding UTF8
        }
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Information ""
Write-Information "=== Sanitization complete ==="
Write-Information "Total changes: $changeCount"
if ($WhatIf) {
    Write-Information "(WhatIf mode — no files were modified)"
}
