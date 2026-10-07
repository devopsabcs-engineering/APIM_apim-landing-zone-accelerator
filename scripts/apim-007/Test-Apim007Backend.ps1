#Requires -Version 7.2
<#
.SYNOPSIS
Functional tests for the Weather REST and SoftwareVersion SOAP backends (direct or via a gateway).

.DESCRIPTION
Weather: GET /WeatherForecast returns 5 typed items with the expected version; GET /api/Version
equals the expected version. SOAP 1.1 (text/xml; charset=utf-8, SOAPAction) envelopes are built
from Get-Apim007WsdlInfo.ps1; responses must be HTTP 200 without Fault, GetSoftwareVersion must
return the expected version and GetAllSoftwareVersions the seeded versions. Optional header
expectations support gateway checks. The whole suite is retried; bodies are never printed.

.PARAMETER WeatherBaseUrl
Weather base URL (for example https://app.azurewebsites.net or <gateway>/weather).

.PARAMETER SoapServiceUrl
SOAP endpoint URL (for example https://app/SoftwareVersionService.asmx or <gateway>/software-version).

.PARAMETER WsdlPath
WSDL used to build the SOAP envelopes.

.PARAMETER ExpectedVersion
Expected application version.

.PARAMETER ExpectedSeededVersions
Expected GetAllSoftwareVersions semantic versions.

.PARAMETER ExpectedWeatherHeaders
Header name/value pairs required on Weather responses.

.PARAMETER ExpectedSoapHeaders
Header name/value pairs required on SOAP responses.

.PARAMETER RetryCount
Attempts before failing.

.PARAMETER RetryDelaySeconds
Delay between attempts.
#>
[CmdletBinding()]
param(
    [string]$WeatherBaseUrl,
    [string]$SoapServiceUrl,
    [string]$WsdlPath,
    [string]$ExpectedVersion,
    [string[]]$ExpectedSeededVersions = @('1.0.0.0', '1.0.1.0', '1.0.2.0'),
    [hashtable]$ExpectedWeatherHeaders = @{},
    [hashtable]$ExpectedSoapHeaders = @{},
    [ValidateRange(1, 100)]
    [int]$RetryCount = 10,
    [ValidateRange(0, 600)]
    [int]$RetryDelaySeconds = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:SoapEnvelopeNamespace = 'http://schemas.xmlsoap.org/soap/envelope/'

function Invoke-Apim007Http {
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Uri,
        [hashtable]$Headers = @{},
        [string]$Body,
        [string]$ContentType
    )
    $request = @{ Method = $Method; Uri = $Uri; Headers = $Headers; SkipHttpErrorCheck = $true; TimeoutSec = 30; MaximumRedirection = 0 }
    if ($Body) { $request.Body = $Body }
    if ($ContentType) { $request.ContentType = $ContentType }
    $response = Invoke-WebRequest @request
    return [pscustomobject]@{ StatusCode = [int]$response.StatusCode; Content = [string]$response.Content; Headers = $response.Headers }
}

function Get-Apim007HeaderValue {
    param($Headers, [string]$Name)
    if (-not $Headers) { return $null }
    foreach ($key in @($Headers.Keys)) {
        if ([string]::Equals([string]$key, $Name, [StringComparison]::OrdinalIgnoreCase)) {
            return (@($Headers[$key]) | Select-Object -First 1)
        }
    }
    return $null
}

function Assert-Apim007ResponseHeader {
    param($Response, [hashtable]$Expected, [string]$Context)
    foreach ($name in $Expected.Keys) {
        $actual = Get-Apim007HeaderValue -Headers $Response.Headers -Name $name
        if ($actual -ne $Expected[$name]) { throw "$Context header '$name' does not have the expected value." }
    }
}

function Assert-Apim007Status {
    param($Response, [string]$Context)
    if ($Response.StatusCode -ne 200) { throw "$Context returned HTTP $($Response.StatusCode)." }
}

function Read-Apim007XmlContent {
    param([string]$Content, [string]$Context)
    $settings = [Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $document = [Xml.XmlDocument]::new()
    $document.XmlResolver = $null
    try {
        $reader = [Xml.XmlReader]::Create([IO.StringReader]::new($Content), $settings)
        try { $document.Load($reader) } finally { $reader.Dispose() }
    }
    catch { throw "$Context did not return well-formed XML." }
    return $document
}

function Test-Apim007WeatherForecast {
    param([string]$BaseUrl, [string]$ExpectedVersion, [hashtable]$ExpectedHeaders = @{})
    $response = Invoke-Apim007Http -Method 'GET' -Uri "$($BaseUrl.TrimEnd('/'))/WeatherForecast" -Headers @{ Accept = 'application/json' }
    Assert-Apim007Status -Response $response -Context 'GET /WeatherForecast'
    Assert-Apim007ResponseHeader -Response $response -Expected $ExpectedHeaders -Context 'GET /WeatherForecast'
    try { $items = @($response.Content | ConvertFrom-Json) } catch { throw 'GET /WeatherForecast did not return JSON.' }
    if ($items.Count -ne 5) { throw "GET /WeatherForecast returned $($items.Count) items; expected 5." }
    foreach ($item in $items) {
        $names = @($item.PSObject.Properties.Name)
        foreach ($required in 'date', 'temperatureC', 'summary', 'version') {
            if ($names -notcontains $required) { throw "GET /WeatherForecast item is missing '$required'." }
        }
        if (-not ($item.date -is [string] -or $item.date -is [datetime]) -or -not "$($item.date)") { throw 'GET /WeatherForecast item date is invalid.' }
        if (-not ($item.temperatureC -is [int] -or $item.temperatureC -is [long])) { throw 'GET /WeatherForecast item temperatureC is not an integer.' }
        if (-not ($item.summary -is [string]) -or -not $item.summary) { throw 'GET /WeatherForecast item summary is invalid.' }
        if ($item.version -ne $ExpectedVersion) { throw 'GET /WeatherForecast item version does not match the expected version.' }
    }
}

function Test-Apim007WeatherVersion {
    param([string]$BaseUrl, [string]$ExpectedVersion, [hashtable]$ExpectedHeaders = @{})
    $response = Invoke-Apim007Http -Method 'GET' -Uri "$($BaseUrl.TrimEnd('/'))/api/Version"
    Assert-Apim007Status -Response $response -Context 'GET /api/Version'
    Assert-Apim007ResponseHeader -Response $response -Expected $ExpectedHeaders -Context 'GET /api/Version'
    $version = $response.Content.Trim()
    if ($version.StartsWith('"')) { $version = [string]($version | ConvertFrom-Json) }
    if ($version -ne $ExpectedVersion) { throw 'GET /api/Version does not match the expected version.' }
}

function New-Apim007SoapEnvelope {
    param([Parameter(Mandatory)]$Operation)
    $settings = [Xml.XmlWriterSettings]::new()
    $settings.Encoding = [Text.UTF8Encoding]::new($false)
    $settings.OmitXmlDeclaration = $false
    $stream = [IO.MemoryStream]::new()
    $writer = [Xml.XmlWriter]::Create($stream, $settings)
    try {
        $writer.WriteStartDocument()
        $writer.WriteStartElement('soap', 'Envelope', $script:SoapEnvelopeNamespace)
        $writer.WriteStartElement('soap', 'Body', $script:SoapEnvelopeNamespace)
        $writer.WriteStartElement('tns', $Operation.InputElementName, $Operation.InputElementNamespace)
        $writer.WriteEndElement()
        $writer.WriteEndElement()
        $writer.WriteEndElement()
        $writer.WriteEndDocument()
    }
    finally { $writer.Dispose() }
    return [Text.UTF8Encoding]::new($false).GetString($stream.ToArray())
}

function Invoke-Apim007SoapOperation {
    param([string]$ServiceUrl, $Operation, [hashtable]$ExpectedHeaders = @{})
    $context = "SOAP $($Operation.Name)"
    $response = Invoke-Apim007Http -Method 'POST' -Uri $ServiceUrl -Headers @{ SOAPAction = "`"$($Operation.SoapAction)`"" } `
        -Body (New-Apim007SoapEnvelope -Operation $Operation) -ContentType 'text/xml; charset=utf-8'
    Assert-Apim007Status -Response $response -Context $context
    Assert-Apim007ResponseHeader -Response $response -Expected $ExpectedHeaders -Context $context
    $document = Read-Apim007XmlContent -Content $response.Content -Context $context
    if ($document.SelectSingleNode("//*[local-name()='Fault']")) { throw "$context returned a SOAP Fault." }
    return @($document.SelectNodes("//*[local-name()='SemanticVersion']") | ForEach-Object { $_.InnerText.Trim() })
}

function Get-Apim007SoapOperation {
    param($WsdlInfo, [string]$Name)
    $operation = @($WsdlInfo.Operations | Where-Object { $_.Name -eq $Name }) | Select-Object -First 1
    if (-not $operation) { throw "WSDL has no operation '$Name'." }
    return $operation
}

function Invoke-Apim007FunctionalCheck {
    param(
        [Parameter(Mandatory)][string]$WeatherBaseUrl,
        [Parameter(Mandatory)][string]$SoapServiceUrl,
        [Parameter(Mandatory)]$WsdlInfo,
        [Parameter(Mandatory)][string]$ExpectedVersion,
        [string[]]$ExpectedSeededVersions = @('1.0.0.0', '1.0.1.0', '1.0.2.0'),
        [hashtable]$ExpectedWeatherHeaders = @{},
        [hashtable]$ExpectedSoapHeaders = @{}
    )
    Test-Apim007WeatherForecast -BaseUrl $WeatherBaseUrl -ExpectedVersion $ExpectedVersion -ExpectedHeaders $ExpectedWeatherHeaders
    Test-Apim007WeatherVersion -BaseUrl $WeatherBaseUrl -ExpectedVersion $ExpectedVersion -ExpectedHeaders $ExpectedWeatherHeaders

    $current = @(Invoke-Apim007SoapOperation -ServiceUrl $SoapServiceUrl -Operation (Get-Apim007SoapOperation -WsdlInfo $WsdlInfo -Name 'GetSoftwareVersion') -ExpectedHeaders $ExpectedSoapHeaders)
    if ($current.Count -ne 1 -or $current[0] -ne $ExpectedVersion) { throw 'SOAP GetSoftwareVersion does not return the expected version.' }

    $all = @(Invoke-Apim007SoapOperation -ServiceUrl $SoapServiceUrl -Operation (Get-Apim007SoapOperation -WsdlInfo $WsdlInfo -Name 'GetAllSoftwareVersions') -ExpectedHeaders $ExpectedSoapHeaders)
    $actualSorted = @($all | Sort-Object)
    $expectedSorted = @($ExpectedSeededVersions | Sort-Object)
    if (($actualSorted -join ',') -ne ($expectedSorted -join ',')) { throw 'SOAP GetAllSoftwareVersions does not return the seeded versions.' }
}

function Invoke-Apim007WithRetry {
    param([Parameter(Mandatory)][scriptblock]$Action, [int]$RetryCount = 10, [int]$RetryDelaySeconds = 15, [string]$Name = 'Check')
    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            & $Action
            Write-Information -MessageData "$Name passed on attempt $attempt." -InformationAction Continue
            return
        }
        catch {
            Write-Warning "$Name attempt $attempt/$RetryCount failed: $($_.Exception.Message)"
            if ($attempt -eq $RetryCount) { throw "$Name failed after $RetryCount attempts: $($_.Exception.Message)" }
            if ($RetryDelaySeconds -gt 0) { Start-Sleep -Seconds $RetryDelaySeconds }
        }
    }
}

function Test-Apim007BackendMain {
    param(
        [Parameter(Mandatory)][string]$WeatherBaseUrl,
        [Parameter(Mandatory)][string]$SoapServiceUrl,
        [Parameter(Mandatory)][string]$WsdlPath,
        [Parameter(Mandatory)][string]$ExpectedVersion,
        [string[]]$ExpectedSeededVersions = @('1.0.0.0', '1.0.1.0', '1.0.2.0'),
        [hashtable]$ExpectedWeatherHeaders = @{},
        [hashtable]$ExpectedSoapHeaders = @{},
        [int]$RetryCount = 10,
        [int]$RetryDelaySeconds = 15
    )
    foreach ($url in $WeatherBaseUrl, $SoapServiceUrl) {
        $uri = $null
        if (-not [Uri]::TryCreate($url, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -notin 'https', 'http') { throw "'$url' is not an absolute URL." }
    }
    $wsdlInfo = & (Join-Path $PSScriptRoot 'Get-Apim007WsdlInfo.ps1') -WsdlPath $WsdlPath
    Invoke-Apim007WithRetry -Name 'Functional checks' -RetryCount $RetryCount -RetryDelaySeconds $RetryDelaySeconds -Action {
        Invoke-Apim007FunctionalCheck -WeatherBaseUrl $WeatherBaseUrl -SoapServiceUrl $SoapServiceUrl -WsdlInfo $wsdlInfo -ExpectedVersion $ExpectedVersion `
            -ExpectedSeededVersions $ExpectedSeededVersions -ExpectedWeatherHeaders $ExpectedWeatherHeaders -ExpectedSoapHeaders $ExpectedSoapHeaders
    }
    return [pscustomobject]@{ Passed = $true; WeatherBaseUrl = $WeatherBaseUrl; SoapServiceUrl = $SoapServiceUrl }
}

if ($MyInvocation.InvocationName -ne '.') { Test-Apim007BackendMain @PSBoundParameters }
