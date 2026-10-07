#Requires -Version 7.2
<#
.SYNOPSIS
Functional and header tests through the 007 APIM gateway.

.DESCRIPTION
Runs Test-Apim007Backend.ps1 against <gateway>/weather and <gateway>/software-version and
requires x-demo-environment, x-demo-release and x-demo-backend-host. Values not given
explicitly come from the target manifest (gateway URL, backend hosts, <env>-007) and the
candidate weather policy (literal x-demo-release).

.PARAMETER GatewayUrl
APIM gateway base URL.

.PARAMETER ManifestPath
Target manifest supplying defaults for gateway URL, environment and backend hosts.

.PARAMETER WsdlPath
WSDL used to build SOAP envelopes.

.PARAMETER ExpectedVersion
Expected application version.

.PARAMETER ExpectedEnvironment
Expected x-demo-environment value.

.PARAMETER ExpectedRelease
Expected x-demo-release value. Overrides PolicyPath.

.PARAMETER PolicyPath
Candidate API policy from which the literal x-demo-release value is read.

.PARAMETER ExpectedWeatherBackendHost
Expected x-demo-backend-host on Weather responses.

.PARAMETER ExpectedSoapBackendHost
Expected x-demo-backend-host on SOAP responses.

.PARAMETER RetryCount
Attempts before failing.

.PARAMETER RetryDelaySeconds
Delay between attempts.
#>
[CmdletBinding()]
param(
    [string]$GatewayUrl,
    [string]$ManifestPath,
    [string]$WsdlPath,
    [string]$ExpectedVersion,
    [string]$ExpectedEnvironment,
    [string]$ExpectedRelease,
    [string]$PolicyPath,
    [string]$ExpectedWeatherBackendHost,
    [string]$ExpectedSoapBackendHost,
    [ValidateRange(1, 100)]
    [int]$RetryCount = 10,
    [ValidateRange(0, 600)]
    [int]$RetryDelaySeconds = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Apim007PolicyRelease {
    param([Parameter(Mandatory)][string]$PolicyPath)
    $settings = [Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $document = [Xml.XmlDocument]::new()
    $reader = [Xml.XmlReader]::Create((Resolve-Path -LiteralPath $PolicyPath).ProviderPath, $settings)
    try { $document.Load($reader) } finally { $reader.Dispose() }
    $value = $document.SelectSingleNode("//set-header[@name='x-demo-release']/value")
    if (-not $value) { throw 'Policy has no x-demo-release header.' }
    $release = $value.InnerText.Trim()
    if (-not $release -or $release -match '@\(|\{\{|\{#') { throw 'Policy x-demo-release must be a non-empty literal.' }
    return $release
}

function Get-Apim007GatewayCheckParameter {
    param(
        [string]$GatewayUrl,
        $Manifest,
        [Parameter(Mandatory)][string]$WsdlPath,
        [Parameter(Mandatory)][string]$ExpectedVersion,
        [string]$ExpectedEnvironment,
        [string]$ExpectedRelease,
        [string]$PolicyPath,
        [string]$ExpectedWeatherBackendHost,
        [string]$ExpectedSoapBackendHost,
        [int]$RetryCount = 10,
        [int]$RetryDelaySeconds = 15
    )
    if ($Manifest) {
        if (-not $GatewayUrl) { $GatewayUrl = [string]$Manifest.apim.gatewayUrl }
        if (-not $ExpectedEnvironment) { $ExpectedEnvironment = "$($Manifest.environment)-007" }
        if (-not $ExpectedWeatherBackendHost) { $ExpectedWeatherBackendHost = [string]$Manifest.backends.apps.weather.defaultHostName }
        if (-not $ExpectedSoapBackendHost) { $ExpectedSoapBackendHost = [string]$Manifest.backends.apps.'software-version'.defaultHostName }
    }
    if (-not $ExpectedRelease -and $PolicyPath) { $ExpectedRelease = Get-Apim007PolicyRelease -PolicyPath $PolicyPath }
    foreach ($pair in @(
            @('GatewayUrl', $GatewayUrl), @('ExpectedEnvironment', $ExpectedEnvironment), @('ExpectedRelease', $ExpectedRelease),
            @('ExpectedWeatherBackendHost', $ExpectedWeatherBackendHost), @('ExpectedSoapBackendHost', $ExpectedSoapBackendHost))) {
        if ([string]::IsNullOrWhiteSpace($pair[1])) { throw "$($pair[0]) is required (directly or via ManifestPath/PolicyPath)." }
    }
    $gatewayUri = $null
    if (-not [Uri]::TryCreate($GatewayUrl, [UriKind]::Absolute, [ref]$gatewayUri) -or $gatewayUri.Scheme -ne 'https') { throw 'GatewayUrl must be an absolute HTTPS URL.' }
    if ($gatewayUri.Host -in $ExpectedWeatherBackendHost, $ExpectedSoapBackendHost) { throw 'Gateway host must differ from the backend hosts.' }
    $gateway = $GatewayUrl.TrimEnd('/')
    return @{
        WeatherBaseUrl         = "$gateway/weather"
        SoapServiceUrl         = "$gateway/software-version"
        WsdlPath               = $WsdlPath
        ExpectedVersion        = $ExpectedVersion
        ExpectedWeatherHeaders = @{ 'x-demo-environment' = $ExpectedEnvironment; 'x-demo-release' = $ExpectedRelease; 'x-demo-backend-host' = $ExpectedWeatherBackendHost }
        ExpectedSoapHeaders    = @{ 'x-demo-environment' = $ExpectedEnvironment; 'x-demo-release' = $ExpectedRelease; 'x-demo-backend-host' = $ExpectedSoapBackendHost }
        RetryCount             = $RetryCount
        RetryDelaySeconds      = $RetryDelaySeconds
    }
}

function Test-Apim007GatewayMain {
    param(
        [string]$GatewayUrl,
        [string]$ManifestPath,
        [Parameter(Mandatory)][string]$WsdlPath,
        [Parameter(Mandatory)][string]$ExpectedVersion,
        [string]$ExpectedEnvironment,
        [string]$ExpectedRelease,
        [string]$PolicyPath,
        [string]$ExpectedWeatherBackendHost,
        [string]$ExpectedSoapBackendHost,
        [int]$RetryCount = 10,
        [int]$RetryDelaySeconds = 15
    )
    $manifest = if ($ManifestPath) { Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json } else { $null }
    $checkParameters = Get-Apim007GatewayCheckParameter -GatewayUrl $GatewayUrl -Manifest $manifest -WsdlPath $WsdlPath -ExpectedVersion $ExpectedVersion `
        -ExpectedEnvironment $ExpectedEnvironment -ExpectedRelease $ExpectedRelease -PolicyPath $PolicyPath `
        -ExpectedWeatherBackendHost $ExpectedWeatherBackendHost -ExpectedSoapBackendHost $ExpectedSoapBackendHost `
        -RetryCount $RetryCount -RetryDelaySeconds $RetryDelaySeconds
    return (& (Join-Path $PSScriptRoot 'Test-Apim007Backend.ps1') @checkParameters)
}

if ($MyInvocation.InvocationName -ne '.') { Test-Apim007GatewayMain @PSBoundParameters }
