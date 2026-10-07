#Requires -Version 7.2
<#
.SYNOPSIS
Writes the 007 release state named value `apim007-release-state`.

.DESCRIPTION
Value: {candidateTag, candidateSha256, sourceSha, runId, status, updatedUtc, history}.
`clean` prepends the candidate to history (last 10, de-duplicated by tag). `dirty` without
candidate parameters keeps the current candidate (needed for the prod retry rule). The
serialized value must stay under 4096 characters. The value is passed to az from a temporary
file, never on the command line.

.PARAMETER ResourceGroup
APIM resource group.

.PARAMETER ServiceName
APIM service name.

.PARAMETER Status
deploying, clean or dirty.

.PARAMETER CandidateTag
Candidate release tag.

.PARAMETER CandidateSha256
Candidate archive SHA256.

.PARAMETER SourceSha
Candidate source commit SHA.

.PARAMETER RunId
Owning workflow run ID. Default $env:GITHUB_RUN_ID.

.PARAMETER OnlyIfOwnedDeploying
No-op unless the current state is `deploying` and owned by RunId (failure/cancel cleanup step).
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ResourceGroup,
    [string]$ServiceName,
    [ValidateSet('deploying', 'clean', 'dirty')]
    [string]$Status,
    [string]$CandidateTag,
    [string]$CandidateSha256,
    [string]$SourceSha,
    [string]$RunId,
    [switch]$OnlyIfOwnedDeploying
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Apim007ReleaseStateName = 'apim007-release-state'
$script:Apim007MaxHistory = 10
$script:Apim007MaxValueLength = 4096

function Invoke-Az {
    param([Parameter(Mandatory)][string[]]$Arguments, [switch]$AllowNotFound)
    $errorFile = [IO.Path]::GetTempFileName()
    try {
        $output = & az @Arguments --only-show-errors 2>$errorFile
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            $errorText = Get-Content -Raw -LiteralPath $errorFile
            if ($AllowNotFound -and $errorText -match '(?i)not ?found') { return $null }
            $firstLine = @(($errorText -split "`n") | Where-Object { $_.Trim() } | Select-Object -First 1)
            throw "az $($Arguments[0..2] -join ' ') failed (exit $exitCode): $firstLine"
        }
        return ($output -join "`n")
    }
    finally { Remove-Item -LiteralPath $errorFile -ErrorAction SilentlyContinue }
}

function ConvertTo-Apim007UtcString {
    param($Value)
    if ($Value -is [datetime]) { return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    return [string]$Value
}

function Read-Apim007CurrentReleaseState {
    param([Parameter(Mandatory)][string]$ResourceGroup, [Parameter(Mandatory)][string]$ServiceName)
    $json = Invoke-Az -AllowNotFound -Arguments @('apim', 'nv', 'show', '--resource-group', $ResourceGroup, '--service-name', $ServiceName,
        '--named-value-id', $script:Apim007ReleaseStateName, '--output', 'json')
    if (-not $json) { return $null }
    $namedValue = $json | ConvertFrom-Json -AsHashtable
    if ($namedValue.ContainsKey('secret') -and $namedValue.secret) { throw 'Release state named value must not be secret.' }
    return ([string]$namedValue.value | ConvertFrom-Json -AsHashtable)
}

function New-Apim007ReleaseStateValue {
    param(
        [hashtable]$Current,
        [Parameter(Mandatory)][ValidateSet('deploying', 'clean', 'dirty')][string]$Status,
        [string]$CandidateTag,
        [string]$CandidateSha256,
        [string]$SourceSha,
        [string]$RunId,
        [datetime]$NowUtc = [datetime]::UtcNow
    )
    if ($Status -eq 'dirty' -and -not $CandidateTag -and $Current) {
        $CandidateTag = [string]$Current.candidateTag
        $CandidateSha256 = [string]$Current.candidateSha256
        $SourceSha = [string]$Current.sourceSha
    }
    if ($CandidateTag -notmatch '^[A-Za-z0-9._\-]{1,128}$') { throw 'CandidateTag is missing or invalid.' }
    if ($CandidateSha256 -notmatch '^[A-Fa-f0-9]{64}$') { throw 'CandidateSha256 is missing or invalid.' }
    if ($SourceSha -notmatch '^[0-9a-f]{40}$') { throw 'SourceSha is missing or invalid.' }
    if ($RunId -notmatch '^[0-9]+$') { throw 'RunId is missing or invalid.' }

    $now = $NowUtc.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $history = [System.Collections.Generic.List[object]]::new()
    if ($Status -eq 'clean') {
        $history.Add([ordered]@{ candidateTag = $CandidateTag; candidateSha256 = $CandidateSha256.ToLowerInvariant(); sourceSha = $SourceSha; cleanUtc = $now })
    }
    $previous = if ($Current -and $Current.ContainsKey('history')) { @($Current.history) } else { @() }
    foreach ($entry in $previous) {
        if ($null -eq $entry -or $history.Count -ge $script:Apim007MaxHistory) { continue }
        if (@($history | Where-Object { $_.candidateTag -eq $entry.candidateTag }).Count -gt 0) { continue }
        $history.Add([ordered]@{
                candidateTag    = [string]$entry.candidateTag
                candidateSha256 = ([string]$entry.candidateSha256).ToLowerInvariant()
                sourceSha       = [string]$entry.sourceSha
                cleanUtc        = ConvertTo-Apim007UtcString $entry.cleanUtc
            })
    }

    $state = [ordered]@{
        candidateTag    = $CandidateTag
        candidateSha256 = $CandidateSha256.ToLowerInvariant()
        sourceSha       = $SourceSha
        runId           = $RunId
        status          = $Status
        updatedUtc      = $now
        history         = $history.ToArray()
    }
    $json = $state | ConvertTo-Json -Depth 5 -Compress
    if ($json.Length -ge $script:Apim007MaxValueLength) { throw "Release state is $($json.Length) characters; the named-value limit is $($script:Apim007MaxValueLength)." }
    return $json
}

function Write-Apim007ReleaseState {
    param([string]$ResourceGroup, [string]$ServiceName, [string]$Json, [bool]$Exists)
    $root = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
    $valueFile = Join-Path $root "apim007-release-state-$([guid]::NewGuid().ToString('N')).json"
    [IO.File]::WriteAllText($valueFile, $Json, [Text.UTF8Encoding]::new($false))
    try {
        $arguments = if ($Exists) {
            @('apim', 'nv', 'update', '--resource-group', $ResourceGroup, '--service-name', $ServiceName,
                '--named-value-id', $script:Apim007ReleaseStateName, '--value', "@$valueFile")
        }
        else {
            @('apim', 'nv', 'create', '--resource-group', $ResourceGroup, '--service-name', $ServiceName,
                '--named-value-id', $script:Apim007ReleaseStateName, '--display-name', $script:Apim007ReleaseStateName,
                '--value', "@$valueFile", '--secret', 'false')
        }
        $null = Invoke-Az -Arguments ($arguments + @('--output', 'none'))
    }
    finally { Remove-Item -LiteralPath $valueFile -ErrorAction SilentlyContinue }
}

function Set-Apim007ReleaseStateMain {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$ResourceGroup,
        [Parameter(Mandatory)][string]$ServiceName,
        [Parameter(Mandatory)][ValidateSet('deploying', 'clean', 'dirty')][string]$Status,
        [string]$CandidateTag,
        [string]$CandidateSha256,
        [string]$SourceSha,
        [string]$RunId = $env:GITHUB_RUN_ID,
        [switch]$OnlyIfOwnedDeploying
    )
    $current = Read-Apim007CurrentReleaseState -ResourceGroup $ResourceGroup -ServiceName $ServiceName
    if ($OnlyIfOwnedDeploying -and -not ($current -and $current.status -eq 'deploying' -and [string]$current.runId -eq $RunId)) {
        Write-Information -MessageData 'Release state not owned by this run in deploying status; unchanged.' -InformationAction Continue
        return [pscustomobject]@{ Changed = $false; Status = if ($current) { $current.status } else { 'none' } }
    }
    $json = New-Apim007ReleaseStateValue -Current $current -Status $Status -CandidateTag $CandidateTag -CandidateSha256 $CandidateSha256 -SourceSha $SourceSha -RunId $RunId
    if ($PSCmdlet.ShouldProcess("$ServiceName/$($script:Apim007ReleaseStateName)", "Set status $Status")) {
        Write-Apim007ReleaseState -ResourceGroup $ResourceGroup -ServiceName $ServiceName -Json $json -Exists ([bool]$current)
    }
    Write-Information -MessageData "Release state set to $Status." -InformationAction Continue
    return [pscustomobject]@{ Changed = $true; Status = $Status; Length = $json.Length }
}

if ($MyInvocation.InvocationName -ne '.') { Set-Apim007ReleaseStateMain @PSBoundParameters }
