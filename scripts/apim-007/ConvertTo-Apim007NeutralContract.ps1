#Requires -Version 7.2
<#
.SYNOPSIS
Normalizes a captured OpenAPI JSON or WSDL contract to an environment-neutral form.

.DESCRIPTION
OpenAPI: removes servers (and Swagger 2 host/schemes); rejects external $ref.
WSDL: sets every soap/soap12 address location to the .invalid SOAP URL; fails closed on
wsdl:import, xsd:import/include/redefine with a location, or any schemaLocation attribute.

.PARAMETER InputPath
Captured contract file.

.PARAMETER OutputPath
Destination for the normalized contract.

.PARAMETER Format
OpenApiJson, Wsdl or Auto (by extension: .json or .wsdl/.xml).

.PARAMETER SoapAddress
Neutral SOAP endpoint written into WSDL address elements.
#>
[CmdletBinding()]
param(
    [string]$InputPath,
    [string]$OutputPath,
    [ValidateSet('Auto', 'OpenApiJson', 'Wsdl')]
    [string]$Format = 'Auto',
    [string]$SoapAddress = 'https://software-version.invalid/SoftwareVersionService.asmx'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:WsdlNamespace = 'http://schemas.xmlsoap.org/wsdl/'
$script:XsdNamespace = 'http://www.w3.org/2001/XMLSchema'
$script:SoapAddressNamespaces = @('http://schemas.xmlsoap.org/wsdl/soap/', 'http://schemas.xmlsoap.org/wsdl/soap12/')

function Write-Apim007Utf8File {
    param([string]$Path, [string]$Content)
    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path -LiteralPath $directory)) { $null = New-Item -ItemType Directory -Path $directory -Force }
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

function Read-Apim007XmlDocument {
    param([Parameter(Mandatory)][string]$Path, [bool]$PreserveWhitespace = $true)
    $settings = [Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $document = [Xml.XmlDocument]::new()
    $document.PreserveWhitespace = $PreserveWhitespace
    $document.XmlResolver = $null
    $reader = [Xml.XmlReader]::Create((Resolve-Path -LiteralPath $Path).ProviderPath, $settings)
    try { $document.Load($reader) } finally { $reader.Dispose() }
    return $document
}

function Assert-Apim007NoExternalReference {
    param($Node)
    if ($Node -is [System.Collections.IDictionary]) {
        foreach ($key in @($Node.Keys)) {
            $value = $Node[$key]
            if ($key -eq '$ref' -and $value -is [string] -and -not $value.StartsWith('#')) {
                throw "External OpenAPI reference is not allowed: '$value'."
            }
            Assert-Apim007NoExternalReference -Node $value
        }
    }
    elseif ($Node -is [System.Collections.IList]) {
        foreach ($item in $Node) { Assert-Apim007NoExternalReference -Node $item }
    }
}

function Remove-Apim007OpenApiServer {
    param([System.Collections.IDictionary]$Document)
    $Document.Remove('servers')
    if ($Document.Contains('paths') -and $Document['paths'] -is [System.Collections.IDictionary]) {
        foreach ($pathItem in $Document['paths'].Values) {
            if ($pathItem -isnot [System.Collections.IDictionary]) { continue }
            $pathItem.Remove('servers')
            foreach ($operation in $pathItem.Values) {
                if ($operation -is [System.Collections.IDictionary]) { $operation.Remove('servers') }
            }
        }
    }
}

function ConvertTo-Apim007NeutralOpenApi {
    param([Parameter(Mandatory)][string]$Content)
    $document = $Content | ConvertFrom-Json -AsHashtable -Depth 100
    if (-not ($document -is [System.Collections.IDictionary]) -or -not ($document.Contains('openapi') -or $document.Contains('swagger'))) {
        throw 'Input is not an OpenAPI or Swagger JSON document.'
    }
    foreach ($key in 'host', 'schemes') { if ($document.Contains('swagger') -and $document.Contains($key)) { $document.Remove($key) } }
    Assert-Apim007NoExternalReference -Node $document
    Remove-Apim007OpenApiServer -Document $document
    return (($document | ConvertTo-Json -Depth 100) -replace "`r`n", "`n") + "`n"
}

function ConvertTo-Apim007NeutralWsdl {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$SoapAddress)
    $address = $null
    if (-not [Uri]::TryCreate($SoapAddress, [UriKind]::Absolute, [ref]$address) -or $address.Scheme -ne 'https') {
        throw 'SoapAddress must be an absolute HTTPS URL.'
    }
    $document = Read-Apim007XmlDocument -Path $Path -PreserveWhitespace $true
    $root = $document.DocumentElement
    if ($root.LocalName -ne 'definitions' -or $root.NamespaceURI -ne $script:WsdlNamespace) { throw 'Input is not a WSDL 1.1 definitions document.' }

    $addressCount = 0
    foreach ($element in $document.SelectNodes('//*')) {
        if ($element.HasAttribute('schemaLocation')) { throw "External schema location on '$($element.LocalName)' is not allowed." }
        if ($element.NamespaceURI -eq $script:WsdlNamespace -and $element.LocalName -eq 'import') { throw 'wsdl:import is not allowed.' }
        if ($element.NamespaceURI -eq $script:XsdNamespace -and $element.LocalName -in 'import', 'include', 'redefine' -and $element.HasAttribute('location')) {
            throw "xsd:$($element.LocalName) with a location is not allowed."
        }
        if ($element.LocalName -eq 'address' -and $element.NamespaceURI -in $script:SoapAddressNamespaces) {
            $element.SetAttribute('location', $SoapAddress)
            $addressCount++
        }
    }
    if ($addressCount -eq 0) { throw 'WSDL has no soap:address or soap12:address element.' }

    $writerSettings = [Xml.XmlWriterSettings]::new()
    $writerSettings.Encoding = [Text.UTF8Encoding]::new($false)
    $stream = [IO.MemoryStream]::new()
    $writer = [Xml.XmlWriter]::Create($stream, $writerSettings)
    try { $document.Save($writer) } finally { $writer.Dispose() }
    return [Text.UTF8Encoding]::new($false).GetString($stream.ToArray())
}

function ConvertTo-Apim007NeutralContractMain {
    param(
        [Parameter(Mandatory)][string]$InputPath,
        [Parameter(Mandatory)][string]$OutputPath,
        [ValidateSet('Auto', 'OpenApiJson', 'Wsdl')][string]$Format = 'Auto',
        [string]$SoapAddress = 'https://software-version.invalid/SoftwareVersionService.asmx'
    )
    if ($Format -eq 'Auto') {
        $Format = switch ([IO.Path]::GetExtension($InputPath).ToLowerInvariant()) {
            '.json' { 'OpenApiJson' }
            { $_ -in '.wsdl', '.xml' } { 'Wsdl' }
            default { throw "Cannot infer contract format from '$InputPath'." }
        }
    }
    $normalized = if ($Format -eq 'OpenApiJson') {
        ConvertTo-Apim007NeutralOpenApi -Content (Get-Content -Raw -LiteralPath $InputPath)
    }
    else {
        ConvertTo-Apim007NeutralWsdl -Path $InputPath -SoapAddress $SoapAddress
    }
    Write-Apim007Utf8File -Path $OutputPath -Content $normalized
    $hash = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash.ToLowerInvariant()
    return [pscustomobject]@{ Format = $Format; Path = $OutputPath; Sha256 = $hash }
}

if ($MyInvocation.InvocationName -ne '.') { ConvertTo-Apim007NeutralContractMain @PSBoundParameters }
