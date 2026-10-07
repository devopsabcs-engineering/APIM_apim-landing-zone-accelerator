#Requires -Version 7.2
<#
.SYNOPSIS
Verifies that every package in an npm lockfile has the same version integrity as the public npm registry.

.DESCRIPTION
The lockfile resolves through an Azure Artifacts proxy feed. This check confirms the proxy served
byte-identical packages by comparing each lockfile sha512 integrity with dist.integrity published by
the upstream registry. npm ci enforces the lockfile integrity on install, so a match here ties the
installed packages to the public registry.

.PARAMETER LockfilePath
Path to package-lock.json (lockfileVersion 2 or 3).

.PARAMETER RegistryUrl
Upstream registry base URL. Defaults to https://registry.npmjs.org/.

.PARAMETER RetryCount
Attempts per package metadata request.
#>
[CmdletBinding()]
param(
    [string]$LockfilePath,
    [string]$RegistryUrl = 'https://registry.npmjs.org/',
    [int]$RetryCount = 3
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Apim007RegistryGet {
    param([string]$Uri)
    Invoke-RestMethod -Uri $Uri -Headers @{ Accept = 'application/json' } -TimeoutSec 60
}

function Get-Apim007LockPackages {
    param([string]$Path)
    $lock = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
    if (-not $lock.ContainsKey('packages')) { throw 'Lockfile has no packages map (lockfileVersion 2 or 3 required).' }
    foreach ($key in $lock.packages.Keys) {
        if ($key -eq '') { continue }
        $entry = $lock.packages[$key]
        if ($entry.ContainsKey('link') -and $entry.link) { continue }
        if (-not $entry.ContainsKey('integrity') -or -not $entry.ContainsKey('version')) {
            throw "Lockfile entry '$key' has no version or integrity."
        }
        $name = if ($entry.ContainsKey('name') -and $entry.name) { $entry.name } else { ($key -split 'node_modules/')[-1] }
        [pscustomobject]@{ Name = $name; Version = $entry.version; Integrity = $entry.integrity }
    }
}

function Test-Apim007LockfileProvenance {
    param([string]$LockfilePath, [string]$RegistryUrl, [int]$RetryCount)
    if (-not $LockfilePath) { throw 'LockfilePath is required.' }
    $base = $RegistryUrl.TrimEnd('/')
    $packages = @(Get-Apim007LockPackages -Path $LockfilePath | Sort-Object Name, Version -Unique)
    if ($packages.Count -eq 0) { throw 'Lockfile contains no packages.' }
    $failures = [System.Collections.Generic.List[string]]::new()
    $documents = @{}
    foreach ($pkg in $packages) {
        if (-not $documents.ContainsKey($pkg.Name)) {
            $encoded = $pkg.Name -replace '/', '%2f'
            $doc = $null
            for ($i = 1; $i -le $RetryCount -and -not $doc; $i++) {
                try { $doc = Invoke-Apim007RegistryGet -Uri "$base/$encoded" } catch { if ($i -lt $RetryCount) { Start-Sleep -Seconds (2 * $i) } }
            }
            $documents[$pkg.Name] = $doc
        }
        $doc = $documents[$pkg.Name]
        if (-not $doc) { $failures.Add("$($pkg.Name): metadata unavailable"); continue }
        $versionDoc = $doc.versions.PSObject.Properties[$pkg.Version]
        if (-not $versionDoc) { $failures.Add("$($pkg.Name)@$($pkg.Version): version not published"); continue }
        if ($versionDoc.Value.dist.integrity -ne $pkg.Integrity) {
            $failures.Add("$($pkg.Name)@$($pkg.Version): integrity mismatch")
        }
    }
    if ($failures.Count -gt 0) {
        $failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
        throw "Lockfile provenance check failed for $($failures.Count) of $($packages.Count) packages against $base."
    }
    Write-Output "Lockfile provenance verified: $($packages.Count) packages match $base."
}

if ($MyInvocation.InvocationName -ne '.') {
    Test-Apim007LockfileProvenance -LockfilePath $LockfilePath -RegistryUrl $RegistryUrl -RetryCount $RetryCount
}
