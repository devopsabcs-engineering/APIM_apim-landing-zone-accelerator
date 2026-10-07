#Requires -Version 7.2
<#
.SYNOPSIS
Regenerates the hosting-only 007 target manifest from fixed deployment records.

.DESCRIPTION
Reads `apim007-apim-<env>` and `apim007-backends-<env>` with `az deployment group show`
(never list-first, never artifacts), validates tenant, subscription, tags, HTTPS URLs and
host separation, then writes canonical compressed JSON and returns its SHA256. When the
AI deployment `apim007-ai-<env>` exists in the APIM resource group, an `ai` section is added.

.PARAMETER Environment
dev or prod.

.PARAMETER ApimResourceGroup
APIM resource group. Default rg-apim-demo-007-<env>-apim.

.PARAMETER BackendResourceGroup
Backend resource group. Default rg-apim-demo-007-<env>-backends.

.PARAMETER ExpectedTenantId
Default $env:EXPECTED_TENANT_ID.

.PARAMETER ExpectedSubscriptionId
Default $env:EXPECTED_SUBSCRIPTION_ID.

.PARAMETER OutputPath
Manifest file to write.
#>
[CmdletBinding()]
param(
    [ValidateSet('dev', 'prod')]
    [string]$Environment,
    [string]$ApimResourceGroup,
    [string]$BackendResourceGroup,
    [string]$ExpectedTenantId,
    [string]$ExpectedSubscriptionId,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Backend deployment output name prefix per app (infra/apim-demo-007/backends.bicep): <prefix>AppName,
# <prefix>AppId, <prefix>DefaultHostName, <prefix>HttpsBaseUrl and <prefix>PrincipalId.
$script:Apim007BackendApps = [ordered]@{ 'weather' = 'weather'; 'software-version' = 'softwareVersion' }
$script:Apim007LegacyHostPattern = '(?i)-00[56](?![0-9])|apim-(dev|prod)-00[56]'

function Invoke-Az {
    param([Parameter(Mandatory)][string[]]$Arguments, [switch]$AllowNotFound)
    $errorFile = [IO.Path]::GetTempFileName()
    try {
        $output = & az @Arguments --only-show-errors 2>$errorFile
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            $errorText = Get-Content -Raw -LiteralPath $errorFile
            if ($AllowNotFound -and $errorText -match '(?i)not ?found') { $global:LASTEXITCODE = 0; return $null }
            $firstLine = @(($errorText -split "`n") | Where-Object { $_.Trim() } | Select-Object -First 1)
            throw "az $($Arguments[0..1] -join ' ') failed (exit $exitCode): $firstLine"
        }
        return ($output -join "`n")
    }
    finally { Remove-Item -LiteralPath $errorFile -ErrorAction SilentlyContinue }
}

function Get-Apim007StringSha256 {
    param([string]$Value)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Assert-Apim007HttpsUrl {
    param([string]$Url, [string]$Context)
    $uri = $null
    if ([string]::IsNullOrWhiteSpace($Url) -or -not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -ne 'https' -or [string]::IsNullOrWhiteSpace($uri.Host)) {
        throw "$Context is not an absolute HTTPS URL."
    }
    if ($uri.Host -match '\.invalid$' -or $uri.Host -match $script:Apim007LegacyHostPattern) { throw "$Context host '$($uri.Host)' is a sentinel or legacy 005/006 host." }
    return $uri
}

function Get-Apim007DeploymentOutput {
    param($Deployment, [string]$Name)
    $outputs = $Deployment.properties.outputs
    $property = if ($outputs) { $outputs.PSObject.Properties[$Name] } else { $null }
    if (-not $property -or [string]::IsNullOrWhiteSpace([string]$property.Value.value)) {
        throw "Deployment '$($Deployment.name)' output '$Name' is missing or empty."
    }
    return [string]$property.Value.value
}

function Get-Apim007Deployment {
    param([string]$ResourceGroup, [string]$Name, [switch]$Optional)
    $json = Invoke-Az -Arguments @('deployment', 'group', 'show', '--resource-group', $ResourceGroup, '--name', $Name, '--output', 'json') -AllowNotFound:$Optional
    if ($Optional -and -not $json) { return $null }
    $deployment = $json | ConvertFrom-Json
    if ($deployment.properties.provisioningState -ne 'Succeeded') { throw "Deployment '$Name' is not Succeeded." }
    return $deployment
}

function Get-Apim007AiSection {
    param($Deployment, [string]$Environment, [string]$ApimResourceGroupId, [string]$SubscriptionId, [string]$GatewayHost)
    $aiServicesId = Get-Apim007DeploymentOutput -Deployment $Deployment -Name 'aiServicesId'
    $contentSafetyId = Get-Apim007DeploymentOutput -Deployment $Deployment -Name 'contentSafetyId'
    $chatDeploymentName = Get-Apim007DeploymentOutput -Deployment $Deployment -Name 'chatDeploymentName'
    if ($chatDeploymentName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$') { throw 'AI chat deployment name is invalid.' }
    $aiUri = Assert-Apim007HttpsUrl -Url (Get-Apim007DeploymentOutput -Deployment $Deployment -Name 'aiServicesEndpoint') -Context 'AI Services endpoint'
    $safetyUri = Assert-Apim007HttpsUrl -Url (Get-Apim007DeploymentOutput -Deployment $Deployment -Name 'contentSafetyEndpoint') -Context 'Content Safety endpoint'
    if ($aiUri.Host -notmatch '^[a-z0-9-]+\.openai\.azure\.com$') { throw "AI Services host '$($aiUri.Host)' is not an Azure OpenAI endpoint." }
    if ($safetyUri.Host -notmatch '^[a-z0-9-]+\.cognitiveservices\.azure\.com$') { throw "Content Safety host '$($safetyUri.Host)' is not a Cognitive Services endpoint." }
    foreach ($id in $aiServicesId, $contentSafetyId) {
        Assert-Apim007SubscriptionScope -ResourceId $id -SubscriptionId $SubscriptionId
        if (-not $id.StartsWith("$ApimResourceGroupId/providers/Microsoft.CognitiveServices/accounts/", [StringComparison]::OrdinalIgnoreCase)) {
            throw "AI resource '$id' is not a Cognitive Services account in the APIM resource group."
        }
        Assert-Apim007ResourceTag -ResourceId $id -Environment $Environment
    }
    if ($aiUri.Host -eq $GatewayHost -or $safetyUri.Host -eq $GatewayHost) { throw 'AI endpoint host equals the APIM gateway host.' }
    return [ordered]@{
        deploymentName     = $Deployment.name
        correlationId      = [string]$Deployment.properties.correlationId
        aiServicesId       = $aiServicesId
        aiServicesHost     = $aiUri.Host
        chatDeploymentName = $chatDeploymentName
        chatUrl            = "https://$($aiUri.Host)/openai/deployments/$chatDeploymentName"
        chatModel          = Get-Apim007DeploymentOutput -Deployment $Deployment -Name 'chatModel'
        contentSafetyId    = $contentSafetyId
        contentSafetyHost  = $safetyUri.Host
        contentSafetyUrl   = "https://$($safetyUri.Host)"
    }
}

function Assert-Apim007ResourceTag {
    param([string]$ResourceId, [string]$Environment)
    $tags = Invoke-Az -Arguments @('resource', 'show', '--ids', $ResourceId, '--query', 'tags', '--output', 'json') | ConvertFrom-Json
    $apimDemo = if ($tags) { $tags.PSObject.Properties['apimDemo'] } else { $null }
    $environmentTag = if ($tags) { $tags.PSObject.Properties['environment'] } else { $null }
    if (-not $apimDemo -or $apimDemo.Value -ne '007' -or -not $environmentTag -or $environmentTag.Value -ne $Environment) {
        throw "Resource '$ResourceId' is not tagged apimDemo=007 and environment=$Environment."
    }
}

function Assert-Apim007SubscriptionScope {
    param([string]$ResourceId, [string]$SubscriptionId)
    if (-not $ResourceId.StartsWith("/subscriptions/$SubscriptionId/", [StringComparison]::OrdinalIgnoreCase)) {
        throw "Resource '$ResourceId' is outside the expected subscription."
    }
}

function New-Apim007TargetManifest {
    param(
        [Parameter(Mandatory)][ValidateSet('dev', 'prod')][string]$Environment,
        [Parameter(Mandatory)][string]$ApimResourceGroup,
        [Parameter(Mandatory)][string]$BackendResourceGroup,
        [Parameter(Mandatory)][string]$ExpectedTenantId,
        [Parameter(Mandatory)][string]$ExpectedSubscriptionId
    )
    $account = Invoke-Az -Arguments @('account', 'show', '--output', 'json') | ConvertFrom-Json
    if ($account.tenantId -ne $ExpectedTenantId) { throw 'Signed-in tenant does not match the expected tenant.' }
    if ($account.id -ne $ExpectedSubscriptionId) { throw 'Signed-in subscription does not match the expected subscription.' }

    $apimDeployment = Get-Apim007Deployment -ResourceGroup $ApimResourceGroup -Name "apim007-apim-$Environment"
    $backendDeployment = Get-Apim007Deployment -ResourceGroup $BackendResourceGroup -Name "apim007-backends-$Environment"

    $apimId = Get-Apim007DeploymentOutput -Deployment $apimDeployment -Name 'apimId'
    $gatewayUrl = (Get-Apim007DeploymentOutput -Deployment $apimDeployment -Name 'apimGatewayUrl').TrimEnd('/')
    $gatewayUri = Assert-Apim007HttpsUrl -Url $gatewayUrl -Context 'APIM gateway URL'
    $apimResourceGroupId = Get-Apim007DeploymentOutput -Deployment $apimDeployment -Name 'resourceGroupId'
    Assert-Apim007SubscriptionScope -ResourceId $apimId -SubscriptionId $ExpectedSubscriptionId
    Assert-Apim007ResourceTag -ResourceId $apimId -Environment $Environment

    $backendResourceGroupId = ($backendDeployment.id -split '/providers/Microsoft.Resources/deployments/')[0]
    Assert-Apim007SubscriptionScope -ResourceId $backendDeployment.id -SubscriptionId $ExpectedSubscriptionId

    $apps = [ordered]@{}
    foreach ($appName in $script:Apim007BackendApps.Keys) {
        $prefix = $script:Apim007BackendApps[$appName]
        $app = [ordered]@{
            name            = Get-Apim007DeploymentOutput -Deployment $backendDeployment -Name "${prefix}AppName"
            id              = Get-Apim007DeploymentOutput -Deployment $backendDeployment -Name "${prefix}AppId"
            defaultHostName = Get-Apim007DeploymentOutput -Deployment $backendDeployment -Name "${prefix}DefaultHostName"
            httpsBaseUrl    = (Get-Apim007DeploymentOutput -Deployment $backendDeployment -Name "${prefix}HttpsBaseUrl").TrimEnd('/')
            principalId     = Get-Apim007DeploymentOutput -Deployment $backendDeployment -Name "${prefix}PrincipalId"
        }
        $uri = Assert-Apim007HttpsUrl -Url $app.httpsBaseUrl -Context "Backend '$appName' base URL"
        if ($uri.Host -ne $app.defaultHostName) { throw "Backend '$appName' base URL host does not match its default host name." }
        if ($uri.Host -eq $gatewayUri.Host) { throw "Backend '$appName' host equals the APIM gateway host." }
        Assert-Apim007SubscriptionScope -ResourceId $app.id -SubscriptionId $ExpectedSubscriptionId
        Assert-Apim007ResourceTag -ResourceId $app.id -Environment $Environment
        $apps[$appName] = $app
    }
    if ($apps['weather'].defaultHostName -eq $apps['software-version'].defaultHostName) { throw 'Backend apps share a host name.' }

    $aiDeployment = Get-Apim007Deployment -ResourceGroup $ApimResourceGroup -Name "apim007-ai-$Environment" -Optional

    $manifest = [ordered]@{
        schemaVersion  = 1
        environment    = $Environment
        tenantId       = $account.tenantId
        subscriptionId = $account.id
        apim           = [ordered]@{
            resourceGroupId = $apimResourceGroupId
            name            = Get-Apim007DeploymentOutput -Deployment $apimDeployment -Name 'apimName'
            id              = $apimId
            location        = Get-Apim007DeploymentOutput -Deployment $apimDeployment -Name 'location'
            gatewayUrl      = $gatewayUrl
            deploymentName  = $apimDeployment.name
            correlationId   = [string]$apimDeployment.properties.correlationId
        }
        backends       = [ordered]@{
            resourceGroupId = $backendResourceGroupId
            deploymentName  = $backendDeployment.name
            correlationId   = [string]$backendDeployment.properties.correlationId
            apps            = $apps
        }
    }
    if ($aiDeployment) {
        $manifest['ai'] = Get-Apim007AiSection -Deployment $aiDeployment -Environment $Environment -ApimResourceGroupId $apimResourceGroupId `
            -SubscriptionId $ExpectedSubscriptionId -GatewayHost $gatewayUri.Host
    }
    return $manifest
}

function Get-Apim007TargetManifestMain {
    param(
        [Parameter(Mandatory)][ValidateSet('dev', 'prod')][string]$Environment,
        [string]$ApimResourceGroup,
        [string]$BackendResourceGroup,
        [string]$ExpectedTenantId = $env:EXPECTED_TENANT_ID,
        [string]$ExpectedSubscriptionId = $env:EXPECTED_SUBSCRIPTION_ID,
        [Parameter(Mandatory)][string]$OutputPath
    )
    if (-not $ExpectedTenantId -or -not $ExpectedSubscriptionId) { throw 'Expected tenant and subscription IDs are required.' }
    if (-not $ApimResourceGroup) { $ApimResourceGroup = "rg-apim-demo-007-$Environment-apim" }
    if (-not $BackendResourceGroup) { $BackendResourceGroup = "rg-apim-demo-007-$Environment-backends" }

    $manifest = New-Apim007TargetManifest -Environment $Environment -ApimResourceGroup $ApimResourceGroup `
        -BackendResourceGroup $BackendResourceGroup -ExpectedTenantId $ExpectedTenantId -ExpectedSubscriptionId $ExpectedSubscriptionId
    $json = $manifest | ConvertTo-Json -Depth 10 -Compress
    $directory = Split-Path -Parent $OutputPath
    if ($directory -and -not (Test-Path -LiteralPath $directory)) { $null = New-Item -ItemType Directory -Path $directory -Force }
    [IO.File]::WriteAllText($OutputPath, $json, [Text.UTF8Encoding]::new($false))
    return [pscustomobject]@{ Path = $OutputPath; Sha256 = Get-Apim007StringSha256 -Value $json; Environment = $Environment }
}

if ($MyInvocation.InvocationName -ne '.') { Get-Apim007TargetManifestMain @PSBoundParameters }
