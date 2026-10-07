#Requires -Version 7.2
<#
.SYNOPSIS
Validates the environment-neutral 007 APIops bundle against the expected inventory.

.PARAMETER InventoryPath
Path to configuration.007.expected-inventory.json.

.PARAMETER BundlePath
Bundle directory. Defaults to the inventory bundleRoot resolved next to the inventory file.

.PARAMETER FilterPath
Ownership filter file. Defaults to the inventory ownershipFilter.path resolved next to the inventory file.

.PARAMETER Mode
Authoring allows API specification files to be missing; Candidate requires them.
#>
[CmdletBinding()]
param(
    [string]$InventoryPath,
    [string]$BundlePath,
    [string]$FilterPath,
    [ValidateSet('Authoring', 'Candidate')]
    [string]$Mode = 'Candidate'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Apim007RequiredInventoryKeys = @(
    'schemaVersion', 'bundleRoot', 'files', 'ownershipFilter', 'resources',
    'overrideTargets', 'allowedBundleSentinels', 'forbiddenNames', 'forbiddenPaths'
)

$script:Apim007CredentialPatterns = @(
    @{ Name = 'SAS signature'; Regex = '(?i)\bsig=' }
    @{ Name = 'password'; Regex = '(?i)password' }
    @{ Name = 'bearer token'; Regex = '(?i)\bBearer\s' }
    @{ Name = 'storage account key'; Regex = '(?i)AccountKey=' }
    @{ Name = 'unresolved pipeline token'; Regex = '\{#' }
    @{ Name = 'redaction marker'; Regex = '\*\*\* REDACTED \*\*\*' }
)

function Assert-Apim007RelativePath {
    param([string]$Path, [string]$Context)
    $segments = if ($Path) { $Path -split '/' } else { @() }
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.Contains('\') -or $Path.StartsWith('/') -or
        $Path -match '^[A-Za-z]:' -or $segments -contains '..' -or $segments -contains '.' -or $segments -contains '') {
        throw "$Context path '$Path' is not a safe relative path."
    }
}

function Read-Apim007Inventory {
    param([Parameter(Mandatory)][string]$Path)
    $inventory = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable
    foreach ($key in $script:Apim007RequiredInventoryKeys) {
        if (-not $inventory.ContainsKey($key)) { throw "Inventory is missing required key '$key'." }
    }
    if ($inventory.schemaVersion -ne 1) { throw "Unsupported inventory schemaVersion '$($inventory.schemaVersion)'." }
    foreach ($file in $inventory.files) { Assert-Apim007RelativePath -Path $file -Context 'Inventory file' }
    Assert-Apim007RelativePath -Path $inventory.bundleRoot -Context 'Inventory bundleRoot'
    Assert-Apim007RelativePath -Path $inventory.ownershipFilter.path -Context 'Inventory ownershipFilter'
    if ($inventory.ownershipFilter.sha256 -notmatch '^[A-Fa-f0-9]{64}$') { throw 'Inventory ownershipFilter.sha256 is not a SHA256 value.' }
    if ($inventory.ContainsKey('aiSettings')) { Assert-Apim007RelativePath -Path $inventory.aiSettings.path -Context 'Inventory aiSettings' }
    return $inventory
}

function Get-Apim007AiSettingsFinding {
    param([Parameter(Mandatory)][string]$SettingsPath, [Parameter(Mandatory)][hashtable]$Inventory)
    $findings = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) { $findings.Add('AI settings file is missing.'); return , $findings.ToArray() }
    try { $settings = Get-Content -Raw -LiteralPath $SettingsPath | ConvertFrom-Json -AsHashtable }
    catch { $findings.Add('AI settings file does not parse.'); return , $findings.ToArray() }
    if ($settings.schemaVersion -ne 1) { $findings.Add('AI settings schemaVersion is not 1.') }
    if ([string]$settings.blocklistName -notmatch '^[a-z0-9][a-z0-9-]{2,63}$') { $findings.Add('AI settings blocklistName is invalid.') }
    if ([string]::IsNullOrWhiteSpace([string]$settings.blocklistFixtureTerm)) { $findings.Add('AI settings blocklistFixtureTerm is empty.') }
    $namedValues = @($Inventory.resources.namedValues)
    foreach ($environment in 'dev', 'prod') {
        $values = if ($settings.environments -is [hashtable]) { $settings.environments[$environment] } else { $null }
        if (-not $values) { $findings.Add("AI settings have no '$environment' environment."); continue }
        if ([string]$values.safetyThreshold -notmatch '^[0-7]$') { $findings.Add("AI settings $environment safetyThreshold must be 0-7.") }
        foreach ($team in @($values.teams.Keys)) {
            if ($Inventory.resources.products -isnot [hashtable] -or -not $Inventory.resources.products.ContainsKey($team)) { $findings.Add("AI settings team '$team' is not an inventory product.") }
            foreach ($suffix in 'tpm', 'daily-quota') {
                if ("ai-$team-$suffix" -notin $namedValues) { $findings.Add("Named value 'ai-$team-$suffix' is not in the inventory.") }
            }
            $limits = $values.teams[$team]
            if ([int64]$limits.tokensPerMinute -le 0 -or [int64]$limits.dailyTokenQuota -lt [int64]$limits.tokensPerMinute) { $findings.Add("AI settings $environment team '$team' limits are invalid.") }
        }
    }
    return , $findings.ToArray()
}

function Get-Apim007RelativePath {
    param([string]$Root, [string]$FullName)
    return ([IO.Path]::GetRelativePath($Root, $FullName) -replace '\\', '/')
}

function Test-Apim007ForbiddenPath {
    param([string]$RelativePath, [string[]]$ForbiddenPaths)
    foreach ($forbidden in $ForbiddenPaths) {
        if ($forbidden.EndsWith('/')) {
            if (($RelativePath + '/').StartsWith($forbidden, [StringComparison]::OrdinalIgnoreCase)) { return $true }
        }
        elseif ([string]::Equals($RelativePath, $forbidden, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Test-Apim007ForbiddenName {
    param([string]$RelativePath, [string[]]$ForbiddenNames)
    foreach ($segment in ($RelativePath -split '/')) {
        foreach ($name in $ForbiddenNames) {
            if ([string]::Equals($segment, $name, [StringComparison]::OrdinalIgnoreCase) -or
                $segment.StartsWith("$name.", [StringComparison]::OrdinalIgnoreCase)) { return $name }
        }
    }
    return $null
}

function Find-Apim007CredentialPattern {
    param([string]$Content)
    $hits = [System.Collections.Generic.List[string]]::new()
    foreach ($pattern in $script:Apim007CredentialPatterns) {
        if ($Content -match $pattern.Regex) { $hits.Add($pattern.Name) }
    }
    foreach ($match in [regex]::Matches($Content, '[A-Za-z0-9+/]{32,}={0,2}')) {
        $token = $match.Value
        $longestSegment = ($token -split '/' | Measure-Object -Property Length -Maximum).Maximum
        if ($token -cmatch '[0-9]' -and $token -cmatch '[A-Z]' -and $token -cmatch '[a-z]' -and $longestSegment -ge 20) {
            $hits.Add('key-like value')
            break
        }
    }
    return $hits.ToArray()
}

function Test-Apim007StructuredContent {
    param([string]$Path, [string]$Content)
    $extension = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    try {
        if ($extension -eq '.json') { $null = $Content | ConvertFrom-Json -AsHashtable }
        elseif ($extension -in '.xml', '.wsdl', '.xsd') {
            $settings = [Xml.XmlReaderSettings]::new()
            $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
            $settings.XmlResolver = $null
            $reader = [Xml.XmlReader]::Create([IO.StringReader]::new($Content), $settings)
            try { while ($reader.Read()) { } } finally { $reader.Dispose() }
        }
        return $true
    }
    catch { return $false }
}

function Get-Apim007BundleFinding {
    param(
        [Parameter(Mandatory)][string]$BundlePath,
        [Parameter(Mandatory)][hashtable]$Inventory,
        [Parameter(Mandatory)][string]$FilterPath,
        [Parameter(Mandatory)][ValidateSet('Authoring', 'Candidate')][string]$Mode
    )
    $findings = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $BundlePath -PathType Container)) { throw "Bundle directory '$BundlePath' does not exist." }
    $root = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $BundlePath).ProviderPath).TrimEnd([char[]]@('\', '/'))
    $prefix = $root + [IO.Path]::DirectorySeparatorChar
    $actual = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)

    foreach ($item in Get-ChildItem -LiteralPath $root -Recurse -Force) {
        $relative = Get-Apim007RelativePath -Root $root -FullName $item.FullName
        if ($item.LinkType -or $item.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
            $findings.Add("Symlink or reparse point is not allowed: $relative")
            continue
        }
        if (-not [IO.Path]::GetFullPath($item.FullName).StartsWith($prefix, [StringComparison]::Ordinal)) {
            $findings.Add("Path escapes the bundle root: $relative")
            continue
        }
        $forbiddenName = Test-Apim007ForbiddenName -RelativePath $relative -ForbiddenNames $Inventory.forbiddenNames
        if ($forbiddenName) { $findings.Add("Forbidden name '$forbiddenName' in path: $relative") }
        $pathToTest = if ($item.PSIsContainer) { "$relative/" } else { $relative }
        if (Test-Apim007ForbiddenPath -RelativePath $pathToTest -ForbiddenPaths $Inventory.forbiddenPaths) {
            $findings.Add("Forbidden path: $relative")
        }
        if (-not $item.PSIsContainer) { $null = $actual.Add($relative) }
    }

    $specificationPattern = '^apis/[^/]+/specification\.[^/]+$'
    $expected = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($file in $Inventory.files) {
        $null = $expected.Add($file)
        if (Test-Apim007ForbiddenPath -RelativePath $file -ForbiddenPaths $Inventory.forbiddenPaths) {
            $findings.Add("Inventory lists a forbidden path: $file")
        }
        if (-not $actual.Contains($file) -and -not ($Mode -eq 'Authoring' -and $file -match $specificationPattern)) {
            $findings.Add("Missing expected file: $file")
        }
    }
    foreach ($file in $actual) {
        if (-not $expected.Contains($file)) { $findings.Add("Unexpected file: $file") }
    }

    foreach ($file in ($actual | Sort-Object)) {
        $content = Get-Content -Raw -LiteralPath (Join-Path $root $file)
        if ($null -eq $content) { $content = '' }
        if (-not (Test-Apim007StructuredContent -Path $file -Content $content)) { $findings.Add("File does not parse: $file") }
        foreach ($name in $Inventory.forbiddenNames) {
            if ($content.IndexOf($name, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $findings.Add("Forbidden name '$name' referenced in: $file") }
        }
        foreach ($hit in (Find-Apim007CredentialPattern -Content $content)) { $findings.Add("Credential pattern ($hit) in: $file") }
    }

    if (-not (Test-Path -LiteralPath $FilterPath -PathType Leaf)) {
        $findings.Add('Ownership filter file is missing.')
    }
    else {
        $filterHash = (Get-FileHash -LiteralPath $FilterPath -Algorithm SHA256).Hash
        if (-not [string]::Equals($filterHash, $Inventory.ownershipFilter.sha256, [StringComparison]::OrdinalIgnoreCase)) {
            $findings.Add('Ownership filter SHA256 does not match the inventory.')
        }
    }
    return , $findings.ToArray()
}

function Test-Apim007BundleMain {
    param(
        [Parameter(Mandatory)][string]$InventoryPath,
        [string]$BundlePath,
        [string]$FilterPath,
        [ValidateSet('Authoring', 'Candidate')][string]$Mode = 'Candidate'
    )
    $inventory = Read-Apim007Inventory -Path $InventoryPath
    $inventoryDirectory = Split-Path -Parent (Resolve-Path -LiteralPath $InventoryPath).ProviderPath
    if (-not $BundlePath) { $BundlePath = Join-Path $inventoryDirectory $inventory.bundleRoot }
    if (-not $FilterPath) { $FilterPath = Join-Path $inventoryDirectory $inventory.ownershipFilter.path }

    $findings = Get-Apim007BundleFinding -BundlePath $BundlePath -Inventory $inventory -FilterPath $FilterPath -Mode $Mode
    if ($inventory.ContainsKey('aiSettings')) {
        $aiFindings = Get-Apim007AiSettingsFinding -SettingsPath (Join-Path $inventoryDirectory $inventory.aiSettings.path) -Inventory $inventory
        $findings = [string[]]@($findings) + [string[]]@($aiFindings)
    }
    if ($findings.Count -gt 0) {
        throw ("Bundle validation failed ({0} finding(s)):`n - {1}" -f $findings.Count, ($findings -join "`n - "))
    }
    Write-Information -MessageData "Bundle validation passed ($Mode, $($inventory.files.Count) inventory files)." -InformationAction Continue
    return [pscustomobject]@{ Mode = $Mode; FileCount = $inventory.files.Count }
}

if ($MyInvocation.InvocationName -ne '.') { Test-Apim007BundleMain @PSBoundParameters }
