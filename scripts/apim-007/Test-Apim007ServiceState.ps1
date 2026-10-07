#Requires -Version 7.2
<#
.SYNOPSIS
Captures or verifies live 007 APIM state that APIops must not change.

.DESCRIPTION
Capture: records SHA256 fingerprints of the canonical ARM properties of the Bicep-owned
named value `instrumentationKey` and logger `apimlogger` (read with `az rest`; values are
never printed). Verify: product `demo` has no group links other than the built-in
`administrators` group and exactly the expected API links,
and the protected fingerprints are unchanged.

.PARAMETER ResourceGroup
APIM resource group.

.PARAMETER ServiceName
APIM service name.

.PARAMETER Mode
Capture or Verify.

.PARAMETER BaselinePath
Fingerprint file written by Capture and read by Verify.

.PARAMETER ProductName
Product to check. Default demo.

.PARAMETER ExpectedApis
Exact API links expected on the product.

.PARAMETER ApiVersion
ARM API version for az rest.
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup,
    [string]$ServiceName,
    [ValidateSet('Capture', 'Verify')]
    [string]$Mode,
    [string]$BaselinePath,
    [string]$ProductName = 'demo',
    [string[]]$ExpectedApis = @('software-version', 'weather'),
    [string]$InventoryPath,
    [string]$ApiVersion = '2024-06-01-preview'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Apim007ProtectedResources = @('namedValues/instrumentationKey', 'loggers/apimlogger', 'diagnostics/applicationinsights')

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

function ConvertTo-Apim007CanonicalJson {
    param($Value)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [System.Collections.IDictionary]) {
        $keys = [string[]]@($Value.Keys)
        [Array]::Sort($keys, [StringComparer]::Ordinal)
        return '{' + ((@(foreach ($key in $keys) { (ConvertTo-Json -InputObject $key -Compress) + ':' + (ConvertTo-Apim007CanonicalJson $Value[$key]) })) -join ',') + '}'
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return '[' + ((@(foreach ($item in $Value) { ConvertTo-Apim007CanonicalJson $item })) -join ',') + ']'
    }
    return (ConvertTo-Json -InputObject $Value -Compress)
}

function Invoke-Apim007ArmGet {
    param([Parameter(Mandatory)][string]$Url)
    return (Invoke-Az -Arguments @('rest', '--method', 'get', '--url', $Url, '--output', 'json') | ConvertFrom-Json -AsHashtable)
}

function Get-Apim007ServiceId {
    param([string]$ResourceGroup, [string]$ServiceName)
    $service = Invoke-Az -Arguments @('apim', 'show', '--resource-group', $ResourceGroup, '--name', $ServiceName, '--output', 'json') | ConvertFrom-Json
    if (-not $service.id) { throw 'APIM service ID not found.' }
    return [string]$service.id
}

function Get-Apim007ProtectedFingerprint {
    param([string]$ServiceId, [string]$ApiVersion)
    $fingerprints = [ordered]@{}
    foreach ($resource in $script:Apim007ProtectedResources) {
        $body = Invoke-Apim007ArmGet -Url "https://management.azure.com$ServiceId/$($resource)?api-version=$ApiVersion"
        if (-not $body -or -not $body.ContainsKey('properties')) { throw "Protected resource '$resource' was not found." }
        $canonical = ConvertTo-Apim007CanonicalJson $body.properties
        $fingerprints[$resource] = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($canonical))).ToLowerInvariant()
    }
    return $fingerprints
}

function Get-Apim007ArmListName {
    param([string]$Url)
    $body = Invoke-Apim007ArmGet -Url $Url
    if ($body.ContainsKey('nextLink') -and $body.nextLink) { throw 'Unexpected paged ARM response.' }
    return @(foreach ($item in @($body.value)) { if ($null -ne $item) { [string]$item.name } })
}

function Test-Apim007ServiceStateMain {
    param(
        [Parameter(Mandatory)][string]$ResourceGroup,
        [Parameter(Mandatory)][string]$ServiceName,
        [Parameter(Mandatory)][ValidateSet('Capture', 'Verify')][string]$Mode,
        [Parameter(Mandatory)][string]$BaselinePath,
        [string]$ProductName = 'demo',
        [string[]]$ExpectedApis = @('software-version', 'weather'),
        [string]$InventoryPath,
        [string]$ApiVersion = '2024-06-01-preview'
    )
    $serviceId = Get-Apim007ServiceId -ResourceGroup $ResourceGroup -ServiceName $ServiceName
    $fingerprints = Get-Apim007ProtectedFingerprint -ServiceId $serviceId -ApiVersion $ApiVersion
    if ($Mode -eq 'Capture') {
        [IO.File]::WriteAllText($BaselinePath, ($fingerprints | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
        Write-Information -MessageData "Captured $($fingerprints.Count) protected fingerprints." -InformationAction Continue
        return [pscustomobject]@{ Mode = 'Capture'; Protected = $fingerprints.Count }
    }

    $failures = [System.Collections.Generic.List[string]]::new()
    $baseline = Get-Content -Raw -LiteralPath $BaselinePath | ConvertFrom-Json -AsHashtable
    foreach ($resource in $fingerprints.Keys) {
        if (-not $baseline.ContainsKey($resource) -or $baseline[$resource] -ne $fingerprints[$resource]) { $failures.Add("Protected resource '$resource' changed.") }
    }
    $products = [ordered]@{ $ProductName = $ExpectedApis }
    if ($InventoryPath) {
        $inventory = Get-Content -Raw -LiteralPath $InventoryPath | ConvertFrom-Json -AsHashtable
        $products = [ordered]@{}
        foreach ($name in $inventory.resources.products.Keys) { $products[$name] = @($inventory.resources.products[$name].apis) }
    }
    foreach ($product in $products.Keys) {
        $productUrl = "https://management.azure.com$serviceId/products/$product"
        # APIM links the built-in administrators group to every new product.
        $groups = @(Get-Apim007ArmListName -Url "$productUrl/groups?api-version=$ApiVersion" | Where-Object { $_ -ne 'administrators' })
        if ($groups.Count -gt 0) { $failures.Add("Product '$product' has group links: $($groups -join ', ').") }
        $apis = @(Get-Apim007ArmListName -Url "$productUrl/apis?api-version=$ApiVersion" | Sort-Object)
        $expected = @($products[$product] | Sort-Object)
        if (($apis -join ',') -ne ($expected -join ',')) { $failures.Add("Product '$product' API links are [$($apis -join ', ')]; expected [$($expected -join ', ')].") }
    }

    if ($failures.Count -gt 0) { throw ("Service state verification failed:`n - " + ($failures -join "`n - ")) }
    Write-Information -MessageData 'Service state verification passed.' -InformationAction Continue
    return [pscustomobject]@{ Mode = 'Verify'; Passed = $true }
}

if ($MyInvocation.InvocationName -ne '.') { Test-Apim007ServiceStateMain @PSBoundParameters }
