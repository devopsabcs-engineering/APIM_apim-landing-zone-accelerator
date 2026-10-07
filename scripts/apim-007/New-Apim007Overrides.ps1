#Requires -Version 7.2
<#
.SYNOPSIS
Builds the APIops CLI override file for one 007 environment from a target manifest.

.DESCRIPTION
Maps every inventory overrideTargets entry to a manifest value, validates it, serializes once
with ConvertTo-Json into RUNNER_TEMP (chmod 600 on Linux) and returns the file SHA256.
Values are never printed.

.PARAMETER ManifestPath
Target manifest produced by Get-Apim007TargetManifest.ps1.

.PARAMETER InventoryPath
configuration.007.expected-inventory.json.

.PARAMETER OutputPath
Override file. Default <RUNNER_TEMP or temp>/apim007-overrides-<env>.json.

.PARAMETER SoapServicePath
Path appended to the SOAP backend base URL.
#>
[CmdletBinding()]
param(
    [string]$ManifestPath,
    [string]$InventoryPath,
    [string]$OutputPath,
    [string]$SoapServicePath = '/SoftwareVersionService.asmx'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Apim007LegacyHostPattern = '(?i)-00[56](?![0-9])|apim-(dev|prod)-00[56]'
$script:Apim007TargetPattern = '^(apis|backends|namedValues)\.([a-z0-9][a-z0-9\-]*)\.(serviceUrl|url|value)$'

function Get-Apim007ManifestApp {
    param($Manifest, [string]$Name)
    $property = $Manifest.backends.apps.PSObject.Properties[$Name]
    if (-not $property) { throw "Manifest has no backend app '$Name'." }
    return $property.Value
}

function Assert-Apim007OverrideUrl {
    param([string]$Url, [string]$Target, [string]$GatewayHost, [string]$ExpectedHost, [string[]]$Sentinels)
    $uri = $null
    if ([string]::IsNullOrWhiteSpace($Url)) { throw "Override '$Target' has no value." }
    if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') { throw "Override '$Target' is not an absolute HTTPS URL." }
    foreach ($sentinel in $Sentinels) { if ($Url.Contains($sentinel)) { throw "Override '$Target' contains bundle sentinel '$sentinel'." } }
    if ($Url -match '\{#|\{\{|\*\*\*') { throw "Override '$Target' contains an unresolved token." }
    if ($uri.Host -match $script:Apim007LegacyHostPattern) { throw "Override '$Target' points at a legacy 005/006 host." }
    if ($uri.Host -eq $GatewayHost) { throw "Override '$Target' routes to the APIM gateway itself." }
    if ($uri.Host -ne $ExpectedHost) { throw "Override '$Target' host does not match the manifest backend host." }
}

function New-Apim007OverrideDocument {
    param(
        [Parameter(Mandatory)]$Manifest,
        [Parameter(Mandatory)][hashtable]$Inventory,
        [string]$SoapServicePath = '/SoftwareVersionService.asmx'
    )
    if ($Manifest.schemaVersion -ne 1 -or $Manifest.environment -notin 'dev', 'prod') { throw 'Manifest schemaVersion or environment is invalid.' }
    $gatewayUri = $null
    if (-not [Uri]::TryCreate([string]$Manifest.apim.gatewayUrl, [UriKind]::Absolute, [ref]$gatewayUri)) { throw 'Manifest gateway URL is invalid.' }
    $weather = Get-Apim007ManifestApp -Manifest $Manifest -Name 'weather'
    $soap = Get-Apim007ManifestApp -Manifest $Manifest -Name 'software-version'
    $weatherBase = ([string]$weather.httpsBaseUrl).TrimEnd('/')
    $soapUrl = if ([string]$soap.httpsBaseUrl) { ([string]$soap.httpsBaseUrl).TrimEnd('/') + $SoapServicePath } else { '' }

    $sources = @{
        'apis.weather.serviceUrl'               = @{ Value = $weatherBase; Host = [string]$weather.defaultHostName }
        'apis.software-version.serviceUrl'      = @{ Value = $soapUrl; Host = [string]$soap.defaultHostName }
        'backends.weather-backend.url'          = @{ Value = $weatherBase; Host = [string]$weather.defaultHostName }
        'backends.software-version-backend.url' = @{ Value = $soapUrl; Host = [string]$soap.defaultHostName }
        'namedValues.demo-environment.value'    = @{ Value = "$($Manifest.environment)-007"; Host = $null }
    }

    $sections = [ordered]@{ apis = [ordered]@{}; backends = [ordered]@{}; namedValues = [ordered]@{} }
    foreach ($target in $Inventory.overrideTargets) {
        if ($target -notmatch $script:Apim007TargetPattern -or -not $sources.ContainsKey($target)) { throw "Unknown override target '$target'." }
        $section = $Matches[1]; $name = $Matches[2]; $property = $Matches[3]
        $known = switch ($section) {
            'apis' { $Inventory.resources.apis.Contains($name) }
            default { @($Inventory.resources[$section]) -contains $name }
        }
        if (-not $known) { throw "Override target '$target' does not match an inventory resource." }

        $value = [string]$sources[$target].Value
        if ($sources[$target].Host) {
            Assert-Apim007OverrideUrl -Url $value -Target $target -GatewayHost $gatewayUri.Host -ExpectedHost $sources[$target].Host -Sentinels $Inventory.allowedBundleSentinels
        }
        elseif ($value -notmatch '^(dev|prod)-007$' -or $value -in $Inventory.allowedBundleSentinels) {
            throw "Override '$target' has an invalid value."
        }
        if (-not $sections[$section].Contains($name)) { $sections[$section][$name] = [ordered]@{} }
        $sections[$section][$name][$property] = $value
    }

    $document = [ordered]@{}
    foreach ($section in $sections.Keys) {
        $names = [string[]]@($sections[$section].Keys)
        if ($names.Count -eq 0) { continue }
        [Array]::Sort($names, [StringComparer]::Ordinal)
        $document[$section] = @(foreach ($name in $names) { [ordered]@{ name = $name; properties = $sections[$section][$name] } })
    }
    return $document
}

function New-Apim007OverridesMain {
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$InventoryPath,
        [string]$OutputPath,
        [string]$SoapServicePath = '/SoftwareVersionService.asmx'
    )
    $manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json
    $inventory = Get-Content -Raw -LiteralPath $InventoryPath | ConvertFrom-Json -AsHashtable
    $document = New-Apim007OverrideDocument -Manifest $manifest -Inventory $inventory -SoapServicePath $SoapServicePath
    $json = (($document | ConvertTo-Json -Depth 10) -replace "`r`n", "`n") + "`n"

    if (-not $OutputPath) {
        $root = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
        $OutputPath = Join-Path $root "apim007-overrides-$($manifest.environment).json"
    }
    $directory = Split-Path -Parent $OutputPath
    if ($directory -and -not (Test-Path -LiteralPath $directory)) { $null = New-Item -ItemType Directory -Path $directory -Force }
    [IO.File]::WriteAllText($OutputPath, '', [Text.UTF8Encoding]::new($false))
    if ($IsLinux -or $IsMacOS) {
        & chmod 600 $OutputPath
        if ($LASTEXITCODE -ne 0) { throw 'chmod 600 on the override file failed.' }
    }
    [IO.File]::WriteAllText($OutputPath, $json, [Text.UTF8Encoding]::new($false))
    $hash = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash.ToLowerInvariant()
    return [pscustomobject]@{ Path = $OutputPath; Sha256 = $hash; Environment = $manifest.environment }
}

if ($MyInvocation.InvocationName -ne '.') { New-Apim007OverridesMain @PSBoundParameters }
