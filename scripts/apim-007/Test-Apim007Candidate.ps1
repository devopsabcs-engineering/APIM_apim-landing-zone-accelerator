#Requires -Version 7.2
<#
.SYNOPSIS
Verifies a frozen 007 candidate archive before any candidate code runs.

.DESCRIPTION
Checks the archive SHA256 against the trusted expected value, rejects non-regular or unsafe
archive entries, extracts into an empty directory, then verifies every per-file SHA256 in
candidate-manifest.json, the exact file set and the digest-form image references.

.PARAMETER ArchivePath
candidate.tar.gz.

.PARAMETER ExpectedSha256
Trusted archive SHA256 (job output or release-state history).

.PARAMETER ExtractPath
New or empty directory to extract into.
#>
[CmdletBinding()]
param(
    [string]$ArchivePath,
    [string]$ExpectedSha256,
    [string]$ExtractPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Apim007ImageRefPattern = '^[a-z0-9.\-]+(:[0-9]+)?/[a-z0-9._/\-]+@sha256:[a-f0-9]{64}$'

function Test-Apim007ImageRef {
    param([string]$ImageRef)
    return [bool]($ImageRef -cmatch $script:Apim007ImageRefPattern)
}

function Get-Apim007TarPath {
    if ($IsWindows) {
        $systemTar = Join-Path $env:SystemRoot 'System32\tar.exe'
        if (Test-Path -LiteralPath $systemTar) { return $systemTar }
    }
    return (Get-Command -Name tar -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
}

function Invoke-Apim007Tar {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $tar = Get-Apim007TarPath
    $output = & $tar @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) { throw "tar $($Arguments[0]) failed (exit $LASTEXITCODE)." }
    return $output
}

function Assert-Apim007SafeEntry {
    param([string]$Path)
    $segments = $Path -split '/'
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.StartsWith('/') -or $Path.Contains('\') -or $Path.Contains(':') -or
        $segments -contains '..' -or $segments -contains '.' -or $segments -contains '') {
        throw "Unsafe candidate path '$Path'."
    }
}

function Get-Apim007ArchiveEntry {
    param([string]$ArchivePath)
    foreach ($line in @(Invoke-Apim007Tar -Arguments @('-tvzf', $ArchivePath))) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if (([string]$line).Substring(0, 1) -notin '-', 'd') { throw 'Candidate archive contains a link or special entry.' }
    }
    $names = [System.Collections.Generic.List[string]]::new()
    foreach ($line in @(Invoke-Apim007Tar -Arguments @('-tzf', $ArchivePath))) {
        $name = ([string]$line).Trim()
        if (-not $name) { continue }
        if ($name.StartsWith('./')) { $name = $name.Substring(2) }
        if ($name.EndsWith('/')) { continue }
        Assert-Apim007SafeEntry -Path $name
        if ($names.Contains($name)) { throw "Candidate archive contains duplicate entry '$name'." }
        $names.Add($name)
    }
    return , $names.ToArray()
}

function Test-Apim007CandidateDirectory {
    param([Parameter(Mandatory)][string]$Path)
    $root = (Resolve-Path -LiteralPath $Path).ProviderPath
    $onDisk = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($item in Get-ChildItem -LiteralPath $root -Recurse -Force) {
        if ($item.LinkType -or $item.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) { throw 'Candidate contains a link or reparse point.' }
        if (-not $item.PSIsContainer) { $null = $onDisk.Add(([IO.Path]::GetRelativePath($root, $item.FullName) -replace '\\', '/')) }
    }
    if (-not $onDisk.Contains('candidate-manifest.json')) { throw 'candidate-manifest.json is missing.' }
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $root 'candidate-manifest.json') | ConvertFrom-Json -AsHashtable
    if ($manifest.schemaVersion -ne 1) { throw 'Unsupported candidate manifest schemaVersion.' }
    if ([string]$manifest.sourceSha -notmatch '^[0-9a-f]{40}$') { throw 'Candidate sourceSha is invalid.' }
    foreach ($key in 'weather', 'soap') {
        if (-not $manifest.images.Contains($key) -or -not (Test-Apim007ImageRef -ImageRef ([string]$manifest.images[$key]))) {
            throw "Candidate image '$key' is not a digest-form reference."
        }
    }

    $listed = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $hashes = @{}
    foreach ($entry in $manifest.files) {
        $relative = [string]$entry.path
        Assert-Apim007SafeEntry -Path $relative
        if (-not $listed.Add($relative)) { throw "Candidate manifest lists '$relative' twice." }
        $hashes[$relative] = ([string]$entry.sha256).ToLowerInvariant()
        if (-not $onDisk.Contains($relative)) { throw "Candidate file '$relative' is missing." }
        $actual = (Get-FileHash -LiteralPath (Join-Path $root $relative) -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $hashes[$relative]) { throw "Candidate file '$relative' hash mismatch." }
    }
    foreach ($file in $onDisk) {
        if ($file -ne 'candidate-manifest.json' -and -not $listed.Contains($file)) { throw "Candidate contains unlisted file '$file'." }
    }
    foreach ($contract in $manifest.contracts.Keys) {
        if (-not $hashes.ContainsKey($contract) -or $hashes[$contract] -ne ([string]$manifest.contracts[$contract]).ToLowerInvariant()) {
            throw "Candidate contract '$contract' does not match its file hash."
        }
    }
    return [pscustomobject]@{
        CandidatePath = $root
        SourceSha     = $manifest.sourceSha
        ApiVersion    = $manifest.apiVersion
        WeatherImage  = $manifest.images.weather
        SoapImage     = $manifest.images.soap
        FileCount     = $listed.Count
    }
}

function Test-Apim007CandidateMain {
    param(
        [Parameter(Mandatory)][string]$ArchivePath,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][string]$ExtractPath
    )
    if ($ExpectedSha256 -notmatch '^[A-Fa-f0-9]{64}$') { throw 'ExpectedSha256 is not a SHA256 value.' }
    $actual = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash
    if (-not [string]::Equals($actual, $ExpectedSha256, [StringComparison]::OrdinalIgnoreCase)) { throw 'Candidate archive SHA256 mismatch.' }

    $entries = Get-Apim007ArchiveEntry -ArchivePath $ArchivePath
    if ($entries -notcontains 'candidate-manifest.json') { throw 'Candidate archive has no candidate-manifest.json.' }
    if ((Test-Path -LiteralPath $ExtractPath) -and (Get-ChildItem -LiteralPath $ExtractPath -Force | Select-Object -First 1)) {
        throw 'ExtractPath must be new or empty.'
    }
    $destination = (New-Item -ItemType Directory -Path $ExtractPath -Force).FullName
    $null = Invoke-Apim007Tar -Arguments @('-xzf', (Resolve-Path -LiteralPath $ArchivePath).ProviderPath, '-C', $destination)
    return Test-Apim007CandidateDirectory -Path $destination
}

if ($MyInvocation.InvocationName -ne '.') { Test-Apim007CandidateMain @PSBoundParameters }
