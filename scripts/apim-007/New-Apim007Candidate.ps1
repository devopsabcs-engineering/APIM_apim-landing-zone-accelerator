#Requires -Version 7.2
<#
.SYNOPSIS
Freezes the 007 release candidate: directory, candidate-manifest.json, candidate.tar.gz and its SHA256.

.DESCRIPTION
Copies the bundle, ownership filter, inventory, tools/apiops-cli/package.json and package-lock.json,
and scripts/apim-007/*.ps1 (not tests) into <OutputDirectory>/candidate using repository-relative
paths, records per-file SHA256, image digests, source SHA and API version, then archives the files
in ordinal path order.

.PARAMETER RepositoryRoot
Repository checkout root. Default: two levels above this script.

.PARAMETER OutputDirectory
New or empty directory receiving candidate/, candidate-manifest.json, candidate.tar.gz and candidate.tar.gz.sha256.

.PARAMETER SourceSha
40-character source commit SHA.

.PARAMETER WeatherImage
Weather image reference in registry/repository@sha256:<digest> form.

.PARAMETER SoapImage
SOAP image reference in registry/repository@sha256:<digest> form.

.PARAMETER ApiVersion
APIM management API version used by the CLI.

.PARAMETER InventoryPath
Inventory path relative to RepositoryRoot.
#>
[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [string]$OutputDirectory,
    [string]$SourceSha,
    [string]$WeatherImage,
    [string]$SoapImage,
    [string]$ApiVersion = '2025-09-01-preview',
    [string]$InventoryPath = 'configuration.007.expected-inventory.json'
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

function New-Apim007Archive {
    param([string]$SourceDirectory, [string[]]$Entries, [string]$ArchivePath)
    $listFile = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllText($listFile, (($Entries -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))
        $arguments = @('-czf', $ArchivePath)
        $version = (& (Get-Apim007TarPath) --version 2>$null | Select-Object -First 1)
        if ($version -match 'GNU tar') { $arguments += @('--owner=0', '--group=0', '--numeric-owner') }
        $arguments += @('-C', $SourceDirectory, '-T', $listFile)
        $null = Invoke-Apim007Tar -Arguments $arguments
    }
    finally { Remove-Item -LiteralPath $listFile -ErrorAction SilentlyContinue }
}

function Get-Apim007CandidateSourceList {
    param([string]$Root, [hashtable]$Inventory, [string]$InventoryRelativePath)
    $files = [System.Collections.Generic.List[string]]::new()
    foreach ($file in $Inventory.files) { $files.Add("$($Inventory.bundleRoot)/$file") }
    $files.Add($Inventory.ownershipFilter.path)
    $files.Add($InventoryRelativePath)
    $files.Add('tools/apiops-cli/package.json')
    $files.Add('tools/apiops-cli/package-lock.json')
    foreach ($scriptFile in Get-ChildItem -LiteralPath (Join-Path $Root 'scripts/apim-007') -Filter '*.ps1' -File) {
        $files.Add("scripts/apim-007/$($scriptFile.Name)")
    }
    $array = $files.ToArray()
    [Array]::Sort($array, [StringComparer]::Ordinal)
    return , $array
}

function New-Apim007CandidateMain {
    param(
        [string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$OutputDirectory,
        [Parameter(Mandatory)][string]$SourceSha,
        [Parameter(Mandatory)][string]$WeatherImage,
        [Parameter(Mandatory)][string]$SoapImage,
        [string]$ApiVersion = '2025-09-01-preview',
        [string]$InventoryPath = 'configuration.007.expected-inventory.json'
    )
    if (-not $RepositoryRoot) { $RepositoryRoot = Join-Path $PSScriptRoot '../..' }
    $root = (Resolve-Path -LiteralPath $RepositoryRoot).ProviderPath
    if ($SourceSha -notmatch '^[0-9a-f]{40}$') { throw 'SourceSha must be a 40-character lowercase commit SHA.' }
    foreach ($image in @($WeatherImage, $SoapImage)) {
        if (-not (Test-Apim007ImageRef -ImageRef $image)) { throw "Image reference '$image' is not in registry/repository@sha256:<digest> form." }
    }
    if ($ApiVersion -notmatch '^\d{4}-\d{2}-\d{2}(-preview)?$') { throw 'ApiVersion is invalid.' }
    $inventoryRelative = $InventoryPath -replace '\\', '/'
    $inventoryFullPath = Join-Path $root $inventoryRelative
    $inventory = Get-Content -Raw -LiteralPath $inventoryFullPath | ConvertFrom-Json -AsHashtable

    $null = & (Join-Path $PSScriptRoot 'Test-Apim007Bundle.ps1') -InventoryPath $inventoryFullPath -Mode Candidate 6>$null

    if ((Test-Path -LiteralPath $OutputDirectory) -and (Get-ChildItem -LiteralPath $OutputDirectory -Force | Select-Object -First 1)) {
        throw 'OutputDirectory must be new or empty.'
    }
    $output = (New-Item -ItemType Directory -Path $OutputDirectory -Force).FullName
    $stage = Join-Path $output 'candidate'
    $null = New-Item -ItemType Directory -Path $stage

    $relativeFiles = Get-Apim007CandidateSourceList -Root $root -Inventory $inventory -InventoryRelativePath $inventoryRelative
    $fileEntries = foreach ($relative in $relativeFiles) {
        $source = Join-Path $root $relative
        $item = Get-Item -LiteralPath $source -Force
        if ($item.PSIsContainer -or $item.LinkType -or $item.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) { throw "Candidate source '$relative' is not a regular file." }
        $destination = Join-Path $stage $relative
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
        Copy-Item -LiteralPath $source -Destination $destination
        [ordered]@{ path = $relative; sha256 = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant() }
    }

    $package = Get-Content -Raw -LiteralPath (Join-Path $stage 'tools/apiops-cli/package.json') | ConvertFrom-Json -AsHashtable
    $cliVersion = [string]$package.dependencies['@azure-tools/apiops-cli']
    if ($cliVersion -notmatch '^\d+\.\d+\.\d+$') { throw 'tools/apiops-cli/package.json must pin @azure-tools/apiops-cli to an exact version.' }

    $contracts = [ordered]@{}
    foreach ($entry in $fileEntries) {
        if ($entry.path -match "^$([regex]::Escape($inventory.bundleRoot))/apis/[^/]+/specification\.[^/]+$") { $contracts[$entry.path] = $entry.sha256 }
    }

    $manifest = [ordered]@{
        schemaVersion       = 1
        sourceSha           = $SourceSha
        apiVersion          = $ApiVersion
        apiopsCliVersion    = $cliVersion
        bundleRoot          = $inventory.bundleRoot
        inventoryPath       = $inventoryRelative
        ownershipFilterPath = $inventory.ownershipFilter.path
        images              = [ordered]@{ weather = $WeatherImage; soap = $SoapImage }
        contracts           = $contracts
        files               = @($fileEntries)
    }
    $manifestJson = (($manifest | ConvertTo-Json -Depth 6) -replace "`r`n", "`n") + "`n"
    $stageManifest = Join-Path $stage 'candidate-manifest.json'
    [IO.File]::WriteAllText($stageManifest, $manifestJson, [Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath $stageManifest -Destination (Join-Path $output 'candidate-manifest.json')

    $archivePath = Join-Path $output 'candidate.tar.gz'
    $entries = [string[]](@($relativeFiles) + 'candidate-manifest.json')
    [Array]::Sort($entries, [StringComparer]::Ordinal)
    New-Apim007Archive -SourceDirectory $stage -Entries $entries -ArchivePath $archivePath
    $archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText((Join-Path $output 'candidate.tar.gz.sha256'), "$archiveHash  candidate.tar.gz`n", [Text.UTF8Encoding]::new($false))

    return [pscustomobject]@{
        CandidateDirectory = $stage
        ManifestPath       = Join-Path $output 'candidate-manifest.json'
        ArchivePath        = $archivePath
        ArchiveSha256      = $archiveHash
        FileCount          = $entries.Count
    }
}

if ($MyInvocation.InvocationName -ne '.') { New-Apim007CandidateMain @PSBoundParameters }
