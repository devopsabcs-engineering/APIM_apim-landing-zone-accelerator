#Requires -Version 7.2
<#
.SYNOPSIS
Reads the 007 release state named value and evaluates the promotion gate.

.DESCRIPTION
State lives in the non-secret APIM named value `apim007-release-state` (outside the bundle).
Missing state means a fresh target. `deploying` owned by a completed run (or an earlier
attempt of this run) becomes `dirty`; owned by an in-progress run it blocks. Prod `dirty`
blocks unless the candidate equals the dirty attempt (retry) or is a rollback to a history
entry. Dev may proceed from `dirty`.

.PARAMETER ResourceGroup
APIM resource group.

.PARAMETER ServiceName
APIM service name.

.PARAMETER Environment
dev or prod.

.PARAMETER CandidateTag
Candidate release tag being deployed or checked.

.PARAMETER CandidateSha256
Candidate archive SHA256.

.PARAMETER IsRollback
Candidate must match a history entry of this state or of AdditionalHistoryStatePath.

.PARAMETER AdditionalHistoryStatePath
JSON output of a previous call (for example the dev state) whose history also qualifies a rollback.

.PARAMETER RequireCleanCandidate
Pass only if the state is clean and records exactly this candidate.

.PARAMETER RunId
Current workflow run ID. Default $env:GITHUB_RUN_ID.

.PARAMETER Repository
owner/repo for gh. Default $env:GITHUB_REPOSITORY.

.PARAMETER Gate
Throw when the gate is not allowed.

.PARAMETER OutputPath
Optional JSON file receiving {exists, state, gate}.
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup,
    [string]$ServiceName,
    [ValidateSet('dev', 'prod')]
    [string]$Environment,
    [string]$CandidateTag,
    [string]$CandidateSha256,
    [switch]$IsRollback,
    [string]$AdditionalHistoryStatePath,
    [switch]$RequireCleanCandidate,
    [string]$RunId,
    [string]$Repository,
    [switch]$Gate,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Apim007ReleaseStateName = 'apim007-release-state'

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

function Invoke-Gh {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = & gh @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) { throw "gh $($Arguments[0..1] -join ' ') failed (exit $LASTEXITCODE)." }
    return ($output -join "`n")
}

function ConvertTo-Apim007UtcString {
    param($Value)
    if ($Value -is [datetime]) { return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    return [string]$Value
}

function ConvertFrom-Apim007ReleaseStateValue {
    param([Parameter(Mandatory)][string]$Value)
    $raw = $Value | ConvertFrom-Json -AsHashtable
    foreach ($key in 'candidateTag', 'candidateSha256', 'sourceSha', 'runId', 'status', 'updatedUtc') {
        if (-not $raw.ContainsKey($key)) { throw "Release state is missing '$key'." }
    }
    if ($raw.status -notin 'deploying', 'clean', 'dirty') { throw "Release state status '$($raw.status)' is invalid." }
    if ([string]$raw.candidateSha256 -notmatch '^[a-fA-F0-9]{64}$') { throw 'Release state candidateSha256 is invalid.' }
    $history = @(
        foreach ($entry in @($(if ($raw.ContainsKey('history')) { $raw.history } else { @() }))) {
            if ($null -eq $entry) { continue }
            [pscustomobject]@{
                candidateTag    = [string]$entry.candidateTag
                candidateSha256 = ([string]$entry.candidateSha256).ToLowerInvariant()
                sourceSha       = [string]$entry.sourceSha
                cleanUtc        = ConvertTo-Apim007UtcString $entry.cleanUtc
            }
        }
    )
    return [pscustomobject]@{
        candidateTag    = [string]$raw.candidateTag
        candidateSha256 = ([string]$raw.candidateSha256).ToLowerInvariant()
        sourceSha       = [string]$raw.sourceSha
        runId           = [string]$raw.runId
        status          = [string]$raw.status
        updatedUtc      = ConvertTo-Apim007UtcString $raw.updatedUtc
        history         = $history
    }
}

function Read-Apim007ReleaseState {
    param([Parameter(Mandatory)][string]$ResourceGroup, [Parameter(Mandatory)][string]$ServiceName)
    $json = Invoke-Az -AllowNotFound -Arguments @('apim', 'nv', 'show', '--resource-group', $ResourceGroup, '--service-name', $ServiceName,
        '--named-value-id', $script:Apim007ReleaseStateName, '--output', 'json')
    if (-not $json) { return $null }
    $namedValue = $json | ConvertFrom-Json -AsHashtable
    if ($namedValue.ContainsKey('secret') -and $namedValue.secret) { throw 'Release state named value must not be secret.' }
    return ConvertFrom-Apim007ReleaseStateValue -Value ([string]$namedValue.value)
}

function Get-Apim007RunStatus {
    param([Parameter(Mandatory)][string]$OwnerRunId, [string]$Repository)
    $arguments = @('run', 'view', $OwnerRunId, '--json', 'status')
    if ($Repository) { $arguments += @('--repo', $Repository) }
    return [string]((Invoke-Gh -Arguments $arguments | ConvertFrom-Json).status)
}

function Find-Apim007HistoryEntry {
    param($State, [string]$CandidateTag, [string]$CandidateSha256)
    if (-not $State -or -not $CandidateTag -or -not $CandidateSha256) { return $false }
    foreach ($entry in @($State.history)) {
        if ($entry.candidateTag -eq $CandidateTag -and [string]::Equals($entry.candidateSha256, $CandidateSha256, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function New-Apim007GateResult {
    param([bool]$Allowed, [string]$EffectiveStatus, [bool]$ConvertedToDirty, [string]$Reason)
    return [pscustomobject]@{ Allowed = $Allowed; EffectiveStatus = $EffectiveStatus; ConvertedToDirty = $ConvertedToDirty; Reason = $Reason }
}

function Resolve-Apim007ReleaseGate {
    param(
        $State,
        [Parameter(Mandatory)][ValidateSet('dev', 'prod')][string]$Environment,
        [string]$CandidateTag,
        [string]$CandidateSha256,
        [switch]$IsRollback,
        $AdditionalHistoryState,
        [switch]$RequireCleanCandidate,
        [string]$CurrentRunId,
        [string]$Repository
    )
    if ($RequireCleanCandidate) {
        $isCleanMatch = $State -and $State.status -eq 'clean' -and $State.candidateTag -eq $CandidateTag -and
            [string]::Equals($State.candidateSha256, $CandidateSha256, [StringComparison]::OrdinalIgnoreCase)
        $status = if ($State) { $State.status } else { 'none' }
        if ($isCleanMatch) { return New-Apim007GateResult $true $status $false "$Environment is clean on this candidate." }
        return New-Apim007GateResult $false $status $false "$Environment is not clean on candidate '$CandidateTag'."
    }

    if ($IsRollback -and -not ((Find-Apim007HistoryEntry -State $State -CandidateTag $CandidateTag -CandidateSha256 $CandidateSha256) -or
            (Find-Apim007HistoryEntry -State $AdditionalHistoryState -CandidateTag $CandidateTag -CandidateSha256 $CandidateSha256))) {
        $status = if ($State) { $State.status } else { 'none' }
        return New-Apim007GateResult $false $status $false "Rollback candidate '$CandidateTag' is not in a release-state history."
    }
    if (-not $State) { return New-Apim007GateResult $true 'none' $false 'No release state; fresh target.' }

    $effective = $State.status
    $converted = $false
    if ($effective -eq 'deploying') {
        if ($CurrentRunId -and $State.runId -eq $CurrentRunId) {
            $effective = 'dirty'; $converted = $true
        }
        else {
            try { $runStatus = Get-Apim007RunStatus -OwnerRunId $State.runId -Repository $Repository }
            catch { return New-Apim007GateResult $false 'deploying' $false "Cannot resolve the status of owner run $($State.runId); resolve manually." }
            if ($runStatus -ne 'completed') {
                return New-Apim007GateResult $false 'deploying' $false "$Environment is being deployed by run $($State.runId) ($runStatus)."
            }
            $effective = 'dirty'; $converted = $true
        }
    }

    if ($effective -eq 'dirty' -and $Environment -eq 'prod') {
        $isRetry = $CandidateTag -and $State.candidateTag -eq $CandidateTag -and
            [string]::Equals($State.candidateSha256, $CandidateSha256, [StringComparison]::OrdinalIgnoreCase)
        if (-not ($isRetry -or $IsRollback)) {
            return New-Apim007GateResult $false 'dirty' $converted 'prod is dirty; only a retry of the dirty candidate or a rollback to history may proceed.'
        }
    }
    return New-Apim007GateResult $true $effective $converted "$Environment gate allowed (state $effective)."
}

function Get-Apim007ReleaseStateMain {
    param(
        [Parameter(Mandatory)][string]$ResourceGroup,
        [Parameter(Mandatory)][string]$ServiceName,
        [Parameter(Mandatory)][ValidateSet('dev', 'prod')][string]$Environment,
        [string]$CandidateTag,
        [string]$CandidateSha256,
        [switch]$IsRollback,
        [string]$AdditionalHistoryStatePath,
        [switch]$RequireCleanCandidate,
        [string]$RunId = $env:GITHUB_RUN_ID,
        [string]$Repository = $env:GITHUB_REPOSITORY,
        [switch]$Gate,
        [string]$OutputPath
    )
    $state = Read-Apim007ReleaseState -ResourceGroup $ResourceGroup -ServiceName $ServiceName
    $additional = $null
    if ($AdditionalHistoryStatePath) {
        $saved = Get-Content -Raw -LiteralPath $AdditionalHistoryStatePath | ConvertFrom-Json -AsHashtable
        if ($saved.state) { $additional = ConvertFrom-Apim007ReleaseStateValue -Value ($saved.state | ConvertTo-Json -Depth 5 -Compress) }
    }
    $gateResult = Resolve-Apim007ReleaseGate -State $state -Environment $Environment -CandidateTag $CandidateTag -CandidateSha256 $CandidateSha256 `
        -IsRollback:$IsRollback -AdditionalHistoryState $additional -RequireCleanCandidate:$RequireCleanCandidate -CurrentRunId $RunId -Repository $Repository
    $result = [pscustomobject]@{ exists = [bool]$state; environment = $Environment; state = $state; gate = $gateResult }
    if ($OutputPath) {
        [IO.File]::WriteAllText($OutputPath, ($result | ConvertTo-Json -Depth 6 -Compress), [Text.UTF8Encoding]::new($false))
    }
    Write-Information -MessageData "Release state ($Environment): $($gateResult.EffectiveStatus); $($gateResult.Reason)" -InformationAction Continue
    if ($Gate -and -not $gateResult.Allowed) { throw "Release gate blocked: $($gateResult.Reason)" }
    return $result
}

if ($MyInvocation.InvocationName -ne '.') { Get-Apim007ReleaseStateMain @PSBoundParameters }
